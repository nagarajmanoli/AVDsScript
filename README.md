Tenant ID: enter your Azure AD tenant GUID and click Sign In. You’ll get an interactive login prompt.
Subscription: pick from the dropdown and click Use.
Refresh Data: pulls the latest AVD resources across resource groups in the selected subscription.
Session Hosts tab:

Select a row, click “Enable New Sessions” or “Disable New Sessions” (drain mode).
User Sessions tab:

Select a row, click “Logoff Selected”.
Status bar shows progress/errors.

Permissions required

Ensure your signed-in identity has adequate roles in the selected subscription/resource groups, such as:

Reader (to list)
Desktop Virtualization Contributor (to manage AVD)
VM-level rights are not required for listed actions above.
