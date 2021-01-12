# OnePlaceLiveSitePnP ReadMe

## Table of Contents

1. [Pre-Requisites](#pre-requisites)
2. [SharePoint Online](#sharepoint-online)
3. [SharePoint On-Premise (2013/2016/2019)](#sharepoint-on-premise-201320162019)


## Pre-requisites


1.  Have either of the following SharePoint environments: SharePoint Online, SharePoint 2019 on-premises, SharePoint 2016 on-premises, SharePoint 2013 on-premises.

2.  PowerShell v3.0 or greater installed on your work environment. 

    Windows 10/8.1 and Windows Server 2012 and greater are all ready to go, but Windows 7 is preinstalled with PowerShell v2.0 and will need to be  upgraded. This can be done by [downloading and installing the Windows Management Framework 4.0](https://www.microsoft.com/en-au/download/details.aspx?id=40855). Download and install either the x64 or x86 version based on your version of Windows 7.

    > ![](./README-Images/image1.png)

3.  (SharePoint On-Premise Only) The SharePoint PnP PowerShell cmdlets. 
You will need to install the the cmdlets on the machine you are running the script from that target your version of SharePoint. If you are using SharePoint Online, the classic PnP Cmdlets will not work. Please see point 4 below.

    > ![](./README-Images/image2.png)

    You will need to logon as a local Administrator to your machine to install the msi file.

    > ![](./README-Images/image3.png)

4.  (SharePoint Online Only) (Multi-Tenant) The latest [PnP.PowerShell](https://pnp.github.io/powershell/articles/installation.html) installed on the machine you are running the script from. You can run this command in PowerShell to install it. 
*Note that you will need to ensure you have uninstalled any previous PnP Cmdlets prior to running this.*
    ```
    Install-Module -Name "PnP.PowerShell" -AllowPrerelease
    ```
    This will also require your Microsoft 365 Administrator to grant App access to the PnP Management Shell in your 365 Tenant. You can check for this ahead of running the script by entering this command in PowerShell
    ```
    Register-PnPManagementShellAccess
    ```

5.  If you need to deploy this Site without GitHub Access (eg, On-Premise deployment without internet access, secure environment), please download the applicable PowerShell Script ([SharePoint 2013/2016/2019](./oneplaceSolutionsSite-Config-v2-onPrem-classic.ps1) or [SharePoint Online](./oneplaceSolutionsSite-Config-v3-SPO-modern.ps1)), template XML ([SharePoint 2013/2016/2019](./oneplaceSolutionsSite-template-v2.xml) or [SharePoint Online](./oneplaceSolutionsSite-template-v3-modern.xml)) and [logo PNG](./oneplacesolutions-logo.png) and place them in '%LocalAppData%\Temp' on the machine you plan to run the script offline from. You must deploy from the downloaded templates within 7 days, or the script will consider them to be stale and attempt to download current versions from GitHub.
	

## SharePoint Online


If you do not want the script to create a Site Collection automatically for you, please create a Team/Group Site from your SharePoint Home as below or create a Team Site(no group) in the SharePoint Admin Center. Note it's URL, and select **Option 1** in the script when prompted.
> ![](./README-Images/createSite.png)
> ![](./README-Images/configureSite.png)

If you would like the script to create the initial Site Collection for you, select **Option 2** in the script when prompted. A Team Site(no group) will be created at 'https://&lt;yourTenant&gt;&#46;sharepoint&#46;com/sites/<b>oneplacesolutions</b>'.

*Note: Option 1 will fail if the site named (by default '\*/oneplacesolutions') already exists.*

*All actions performed with the script will be logged to 'OPSScriptLog.txt' in your Documents folder (or possibly under the Administrator account's Documents if running PowerShell as an Administrator). When requesting assistance with this script please send this log file as an attachment. This directory can be changed in-script.*

*The log file will be uploaded to the Documents folder in the Solutions Site at the end of deployment for your record keeping.*


1.  Start PowerShell on your machine:

    > ![](./README-Images/image4.png)

2.  Copy and paste the following command into your PowerShell command
    window and hit enter:

    ```PowerShell
    Invoke-Expression (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/OnePlaceSolutions/OnePlaceLiveSitePnP/master/oneplaceSolutionsSite-Config-v4-SPO-modern.ps1')
    ```

    > ![](./README-Images/invokestringSPO.png)

3.  The PowerShell script will execute and begin logging actions to the noted log file path. You will be prompted to choose whether to deploy the template to an existing Site Collection, or create a new Site Collection and deploy the template afterwards. 

    If you have created a Group/Team Site, or the Solutions Site already exists and you wish to update it, or a problem was encountered during initial deployment, select **Option 1**. You will be prompted to enter the URL of the existing Solutions Site.

    > ![](./README-Images/menu.png)
    
	If you are deploying to a Group Site or existing Site and have selected **Option 1** please move on to Step 4.
	
	3a.  (**Option 2 Only**) Please enter the SharePoint Root Site Collection URL and press enter. For example, 'htt<span>ps://contoso&#46;sharepoint&#46;com':

	3b.  (**Option 2 Only**) You will be asked to enter your credentials for Microsoft 365 \/ SharePoint Online.

	3c.  (**Option 2 Only**) You will then be asked to enter an email address for the owner of this Site Collection. Enter the same email address you logged in with, as only the Site Owner can deploy the script to the new Site Collection it's current state. You can change the Site Owner after deployment if you wish:

	> ![](./README-Images/enterownerSPO.png)

	3d.  (**Option 2 Only**) SharePoint will start provisioning the Site. Please leave the PowerShell window open while this happens, it will automatically resume the script when the Site is ready to configure. Depending on Microsoft service usage this can take up to 30 minutes, but creation usually occurs in less than 10 minutes.

	> ![](./README-Images/sitecreationSPO.png)

4.  Once the Site Collection URL has been entered (or the Site Collection has been created as part of Option 2) the script will start configuring it for use.

    > ![](./README-Images/siteconfigurationSPO.png)
	
5.  When configuration has completed, your Solutions Site URL, License List URL and License List ID will be displayed (these are also in the log file, and will be visible in the Solutions Site). You may also opt to automatically email these details now to OnePlace Solutions. These URLs will be kept on file for support purposes, and the License List ID will be required for your Production License.

    > ![](./README-Images/configurationcompleteSPO.png)
6.  Finally, press Enter to open your Solutions Site.\
    The homepage contains some useful links for training and support resources, and when you have a Production license an overview of your License usage.\
    ![](./README-Images/solutionssiteSPO.png)
    Scrolling down you can always find your Client Configuration Details (The License List URL and Solutions Site URL), and your License List ID. If you did not opt to email these automatically in the previous step, please email the License List ID to 'success@oneplacesolutions.com' when procuring a Production License. If you have received a Production license or Time Expiry Key, you may attach it here.\
    ![](./README-Images/solutionssitedetailsSPO.png)


## SharePoint On-Premise (2013/2016/2019)
1.  In Central Administration, create a site collection with the URL 'oneplacesolutions' and based on the Team Site template (Team Site (classic) if using SharePoint 2016/2019), note it's URL for later:

    ![](./README-Images/createsitecollection-onpremise-v2.png)

2.  Start PowerShell on your machine:

    ![](./README-Images/image4.png)

3.  Copy and paste the following command into your PowerShell command
    window and hit enter:

    ```PowerShell
    Invoke-Expression (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/OnePlaceSolutions/OnePlaceLiveSitePnP/master/oneplaceSolutionsSite-Config-v2-onPrem-classic.ps1')
    ```

    ![](./README-Images/ps1command.png)


4.  The PowerShell script will execute and prompt you to enter the Site Collection URL of the site collection you manually created in Step 1. You can either type it in or copy and paste the url into the command window and hit enter:

    ![](./README-Images/enterurl.png)

5.  You will be asked to enter your credentials for SharePoint. For on-premise it will be your domain\\username:

    ![](./README-Images/credentials.png)

6.  The OnePlace Solutions site template will then be downloaded and the script will start configuring it for use:


    ![](./README-Images/applychanges.png)
7.  When configuration has completed, your Solutions Site URL, License List URL and License List ID will be displayed (these are also in the log file, and will be visible in the Solutions Site). You may also opt to automatically email these details now to OnePlace Solutions. These URLs will be kept on file for support purposes, and the License List ID will be required for your Production License.

    ![](./README-Images/applyingchangestosite.png)
8.  Finally, press Enter to open your Solutions Site.

	The homepage contains some useful links for training and support resources, and when you have a Production license an overview of your License usage. 
	![](./README-Images/solutionssiteonPrem.png)
	
	Here you can always find your Client Configuration Details (The License List URL and Solutions Site URL), and your License List ID. If you did not opt to email these automatically in the previous step, please email the License List ID to 'success@oneplacesolutions.com' when procuring a Production License. If you have received a Production license or Time Expiry Key, you may attach it here.

