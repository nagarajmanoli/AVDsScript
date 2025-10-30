param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Ensure-AzModules {
    $modules = @('Az.Accounts','Az.Resources','Az.DesktopVirtualization')
    foreach ($m in $modules) {
        if (-not (Get-Module -ListAvailable -Name $m)) {
            try { Install-Module -Name $m -Scope CurrentUser -Force -AllowClobber -Repository PSGallery | Out-Null } catch {}
        }
        Import-Module $m -ErrorAction Stop | Out-Null
    }
}

function Connect-Tenant {
    param(
        [string]$TenantId
    )
    Connect-AzAccount -Tenant $TenantId -ErrorAction Stop | Out-Null
}

function Get-Subscriptions {
    Get-AzSubscription | Sort-Object Name
}

function Set-SubscriptionContext {
    param([string]$SubscriptionId)
    Select-AzSubscription -SubscriptionId $SubscriptionId | Out-Null
}

function Get-AllHostPools {
    $result = @()
    $rgs = Get-AzResourceGroup
    foreach ($rg in $rgs) {
        try { $items = Get-AzWvdHostPool -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop } catch { $items = @() }
        foreach ($i in $items) { $result += [pscustomobject]@{ Name=$i.Name; ResourceGroup=$rg.ResourceGroupName; Location=$i.Location; Type=$i.HostPoolType; LoadBalancerType=$i.LoadBalancerType; MaxSessionLimit=$i.MaxSessionLimit; FriendlyName=$i.FriendlyName; ValidationEnvironment=$i.ValidationEnvironment } }
    }
    $result
}

function Get-AllWorkspaces {
    $result = @()
    $rgs = Get-AzResourceGroup
    foreach ($rg in $rgs) {
        try { $items = Get-AzWvdWorkspace -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop } catch { $items = @() }
        foreach ($i in $items) { $result += [pscustomobject]@{ Name=$i.Name; ResourceGroup=$rg.ResourceGroupName; Location=$i.Location; Description=$i.Description; FriendlyName=$i.FriendlyName } }
    }
    $result
}

function Get-AllAppGroups {
    $result = @()
    $rgs = Get-AzResourceGroup
    foreach ($rg in $rgs) {
        try { $items = Get-AzWvdApplicationGroup -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop } catch { $items = @() }
        foreach ($i in $items) { $result += [pscustomobject]@{ Name=$i.Name; ResourceGroup=$rg.ResourceGroupName; Location=$i.Location; FriendlyName=$i.FriendlyName; Description=$i.Description; Type=$i.ApplicationGroupType; HostPoolArmPath=$i.HostPoolArmPath } }
    }
    $result
}

function Get-AllSessionHosts {
    $result = @()
    $rgs = Get-AzResourceGroup
    foreach ($rg in $rgs) {
        try { $hostpools = Get-AzWvdHostPool -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop } catch { $hostpools = @() }
        foreach ($hp in $hostpools) {
            try { $items = Get-AzWvdSessionHost -ResourceGroupName $rg.ResourceGroupName -HostPoolName $hp.Name -ErrorAction Stop } catch { $items = @() }
            foreach ($i in $items) { $result += [pscustomobject]@{ HostPool=$hp.Name; ResourceGroup=$rg.ResourceGroupName; Name=$i.Name; Status=$i.Status; SxSStackVersion=$i.SxSStackVersion; Sessions=$i.Session; AllowNewSession=$i.AllowNewSession; AssignedUser=$i.AssignedUser } }
        }
    }
    $result
}

function Get-AllUserSessions {
    $result = @()
    $rgs = Get-AzResourceGroup
    foreach ($rg in $rgs) {
        try { $hostpools = Get-AzWvdHostPool -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop } catch { $hostpools = @() }
        foreach ($hp in $hostpools) {
            try { $sessionHosts = Get-AzWvdSessionHost -ResourceGroupName $rg.ResourceGroupName -HostPoolName $hp.Name -ErrorAction Stop } catch { $sessionHosts = @() }
            foreach ($sh in $sessionHosts) {
                try { $items = Get-AzWvdUserSession -ResourceGroupName $rg.ResourceGroupName -HostPoolName $hp.Name -SessionHostName $sh.Name -ErrorAction Stop } catch { $items = @() }
                foreach ($i in $items) { $result += [pscustomobject]@{ HostPool=$hp.Name; ResourceGroup=$rg.ResourceGroupName; SessionHost=$sh.Name; UserPrincipalName=$i.UserPrincipalName; SessionState=$i.SessionState; Id=$i.Id; ApplicationType=$i.ApplicationType; ActiveDirectoryUserName=$i.ActiveDirectoryUserName } }
            }
        }
    }
    $result
}

function Logoff-UserSession {
    param([string]$ResourceGroup,[string]$HostPool,[string]$SessionHost,[int]$SessionId)
    try { Remove-AzWvdUserSession -ResourceGroupName $ResourceGroup -HostPoolName $HostPool -SessionHostName $SessionHost -Id $SessionId -Force -ErrorAction Stop | Out-Null; return $true } catch { return $false }
}

function Toggle-SessionHostAllowNew {
    param([string]$ResourceGroup,[string]$HostPool,[string]$SessionHost,[bool]$Allow)
    try { Update-AzWvdSessionHost -ResourceGroupName $ResourceGroup -HostPoolName $HostPool -Name $SessionHost -AllowNewSession:$Allow -ErrorAction Stop | Out-Null; return $true } catch { return $false }
}

Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="AVD Admin" Height="700" Width="1100" WindowStartupLocation="CenterScreen">
  <Grid Margin="10">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="*"/>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="*"/>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <TextBlock Grid.Row="0" Grid.Column="0" Text="Tenant ID" VerticalAlignment="Center" Margin="0,0,8,0"/>
    <TextBox x:Name="TenantBox" Grid.Row="0" Grid.Column="0" Grid.ColumnSpan="2" Margin="70,0,8,0"/>
    <Button x:Name="SignInBtn" Grid.Row="0" Grid.Column="2" Content="Sign In" Width="100"/>

    <TextBlock Grid.Row="1" Grid.Column="0" Text="Subscription" VerticalAlignment="Center" Margin="0,8,8,0"/>
    <ComboBox x:Name="SubCombo" Grid.Row="1" Grid.Column="1" Grid.ColumnSpan="2" Margin="0,8,8,0" DisplayMemberPath="Name" SelectedValuePath="Id"/>
    <Button x:Name="SetSubBtn" Grid.Row="1" Grid.Column="3" Content="Use" Width="80" Margin="0,8,0,0"/>
    <Button x:Name="RefreshBtn" Grid.Row="1" Grid.Column="4" Content="Refresh Data" Width="120" Margin="8,8,0,0"/>

    <TabControl x:Name="MainTabs" Grid.Row="2" Grid.Column="0" Grid.ColumnSpan="5" Margin="0,10,0,10">
      <TabItem Header="Host Pools">
        <DataGrid x:Name="HostPoolsGrid" AutoGenerateColumns="True" IsReadOnly="True"/>
      </TabItem>
      <TabItem Header="Workspaces">
        <DataGrid x:Name="WorkspacesGrid" AutoGenerateColumns="True" IsReadOnly="True"/>
      </TabItem>
      <TabItem Header="App Groups">
        <DataGrid x:Name="AppGroupsGrid" AutoGenerateColumns="True" IsReadOnly="True"/>
      </TabItem>
      <TabItem Header="Session Hosts">
        <DockPanel>
          <StackPanel Orientation="Horizontal" DockPanel.Dock="Top" Margin="0,0,0,6">
            <Button x:Name="EnableNewSessionsBtn" Content="Enable New Sessions" Margin="0,0,6,0"/>
            <Button x:Name="DrainModeBtn" Content="Disable New Sessions"/>
          </StackPanel>
          <DataGrid x:Name="SessionHostsGrid" AutoGenerateColumns="True" IsReadOnly="True"/>
        </DockPanel>
      </TabItem>
      <TabItem Header="User Sessions">
        <DockPanel>
          <StackPanel Orientation="Horizontal" DockPanel.Dock="Top" Margin="0,0,0,6">
            <Button x:Name="LogoffBtn" Content="Logoff Selected"/>
          </StackPanel>
          <DataGrid x:Name="UserSessionsGrid" AutoGenerateColumns="True" IsReadOnly="True"/>
        </DockPanel>
      </TabItem>
    </TabControl>

    <StatusBar Grid.Row="3" Grid.ColumnSpan="5">
      <StatusBarItem>
        <TextBlock x:Name="StatusText" Text="Ready"/>
      </StatusBarItem>
    </StatusBar>
  </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$TenantBox = $window.FindName('TenantBox')
$SignInBtn = $window.FindName('SignInBtn')
$SubCombo = $window.FindName('SubCombo')
$SetSubBtn = $window.FindName('SetSubBtn')
$RefreshBtn = $window.FindName('RefreshBtn')
$HostPoolsGrid = $window.FindName('HostPoolsGrid')
$WorkspacesGrid = $window.FindName('WorkspacesGrid')
$AppGroupsGrid = $window.FindName('AppGroupsGrid')
$SessionHostsGrid = $window.FindName('SessionHostsGrid')
$UserSessionsGrid = $window.FindName('UserSessionsGrid')
$StatusText = $window.FindName('StatusText')
$EnableNewSessionsBtn = $window.FindName('EnableNewSessionsBtn')
$DrainModeBtn = $window.FindName('DrainModeBtn')
$LogoffBtn = $window.FindName('LogoffBtn')

function Set-Status { param([string]$t) $StatusText.Text = $t }

function Load-SubscriptionsUI {
    $subs = Get-Subscriptions
    $SubCombo.ItemsSource = $subs
    if ($subs.Count -gt 0) { $SubCombo.SelectedIndex = 0 }
}

function Load-AVDDataUI {
    Set-Status 'Loading AVD data...'
    $HostPoolsGrid.ItemsSource = Get-AllHostPools
    $WorkspacesGrid.ItemsSource = Get-AllWorkspaces
    $AppGroupsGrid.ItemsSource = Get-AllAppGroups
    $SessionHostsGrid.ItemsSource = Get-AllSessionHosts
    $UserSessionsGrid.ItemsSource = Get-AllUserSessions
    Set-Status 'Data loaded'
}

$SignInBtn.Add_Click({
    try {
        Set-Status 'Ensuring modules...'
        Ensure-AzModules
        Set-Status 'Signing in...'
        $tid = ($TenantBox.Text).Trim()
        if (-not $tid) { [System.Windows.MessageBox]::Show('Enter Tenant ID'); return }
        Connect-Tenant -TenantId $tid
        Load-SubscriptionsUI
        Set-Status 'Signed in'
    } catch {
        [System.Windows.MessageBox]::Show("Sign-in failed: $($_.Exception.Message)")
        Set-Status 'Sign-in failed'
    }
})

$SetSubBtn.Add_Click({
    if (-not $SubCombo.SelectedValue) { [System.Windows.MessageBox]::Show('Select a subscription'); return }
    try {
        Set-Status 'Switching subscription...'
        Set-SubscriptionContext -SubscriptionId $SubCombo.SelectedValue
        Set-Status 'Subscription set'
    } catch {
        [System.Windows.MessageBox]::Show("Failed to set subscription: $($_.Exception.Message)")
        Set-Status 'Failed to set subscription'
    }
})

$RefreshBtn.Add_Click({
    try { Load-AVDDataUI } catch { [System.Windows.MessageBox]::Show("Refresh failed: $($_.Exception.Message)") }
})

$EnableNewSessionsBtn.Add_Click({
    $row = $SessionHostsGrid.SelectedItem
    if (-not $row) { [System.Windows.MessageBox]::Show('Select a session host row'); return }
    $ok = Toggle-SessionHostAllowNew -ResourceGroup $row.ResourceGroup -HostPool $row.HostPool -SessionHost $row.Name -Allow $true
    if ($ok) { Load-AVDDataUI } else { [System.Windows.MessageBox]::Show('Operation failed') }
})

$DrainModeBtn.Add_Click({
    $row = $SessionHostsGrid.SelectedItem
    if (-not $row) { [System.Windows.MessageBox]::Show('Select a session host row'); return }
    $ok = Toggle-SessionHostAllowNew -ResourceGroup $row.ResourceGroup -HostPool $row.HostPool -SessionHost $row.Name -Allow $false
    if ($ok) { Load-AVDDataUI } else { [System.Windows.MessageBox]::Show('Operation failed') }
})

$LogoffBtn.Add_Click({
    $row = $UserSessionsGrid.SelectedItem
    if (-not $row) { [System.Windows.MessageBox]::Show('Select a user session row'); return }
    $sid = 0
    try { $sid = [int]($row.Id.ToString().Split('/')[-1]) } catch { $sid = 0 }
    if ($sid -le 0) { [System.Windows.MessageBox]::Show('Could not parse session Id'); return }
    $ok = Logoff-UserSession -ResourceGroup $row.ResourceGroup -HostPool $row.HostPool -SessionHost $row.SessionHost -SessionId $sid
    if ($ok) { Load-AVDDataUI } else { [System.Windows.MessageBox]::Show('Operation failed') }
})

$window.Add_SourceInitialized({ Set-Status 'Ready' })
[void]$window.ShowDialog()
