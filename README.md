## Pre-requisites


1.  Have either of the following SharePoint environments: SharePoint Online, SharePoint 2019 on-premises, SharePoint 2016 on-premises, SharePoint 2013
    on-premises.

2.  PowerShell v3.0 or greater installed on your work environment. 

    Windows 10/8.1 and Windows Server 2012 and greater are all ready to go, but Windows 7 is preinstalled with PowerShell v2.0 and will need to be  upgraded. This can be done by [downloading and installing the Windows Management Framework 4.0](https://www.microsoft.com/en-au/download/details.aspx?id=40855). Download and install either the x64 or x86 version based on your version of Windows 7.

    ![](./README-Images/image1.png)

3.  The latest [SharePoint PnP PowerShell cmdlets](https://github.com/SharePoint/PnP-PowerShell/releases). You will need to install the the cmdlets that target your version of SharePoint.

    ![](./README-Images/image2.png)

    If you already have the PnP Powershell cmdlets installed, make sure you are on the most recent version by upgrading them by uninstalling the old version and [installing the new version](https://github.com/SharePoint/PnP-PowerShell/releases).

    You will need to logon as a local Administrator to your machine to install the msi file.

    ![](./README-Images/image3.png)

## SharePoint On-Premise (2013/2016/2019)
In Central Administration, create a site collection based on the Team Site template

![](./README-Images/createsitecollection-onpremise-v2.png)

## SharePoint Online
Site creation will be performed automatically with the configuration script. The site will be created at 'http://&lt;<span>yourSharePoint&gt;.sharepoint.com/sites/<b>oneplacesolutions</b>'. This can be overridden by downloading and running the PowerShell script locally and defining the '-solutionssite' parameter:
![](./README-Images/scriptoverrideSPO.png)

Note that the script will not run if the site named already exists.
All actions performed with the script will be logged to 'OPSScriptLog.txt' in your Documents folder (or under the Administrator account's Documents if running PowerShell as an Administrator). This log file will be uploaded to the Documents folder in the Solutions Site at the end of deployment for your record keeping.

### Run the PnP PowerShell Script to create and configure the Solutions Site

1.  Start PowerShell on your machine:

    ![](./README-Images/image4.png)

2.  Copy and paste the following command into your PowerShell command
    window and hit enter:

    ```PowerShell
    Invoke-Expression (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/OnePlaceSolutions/OnePlaceLiveSitePnP/master/oneplaceSolutionsSite-Config-v3-SPO-modern.ps1')
    ```

    ![](./README-Images/invokestringSPO.png)


3.  The PowerShell script will execute, begin logging and tell you the log file path, and prompt you to enter your SharePoint Tenant name and hit enter. For example, if your Root SharePoint Site Collection is 'https://contoso.sharepoint.com', just enter 'contoso':

    ![](./README-Images/entertenantSPO.png)

4.  You will be asked to enter your credentials for Microsoft 365 \/ SharePoint. For SharePoint Online this will be your email address

5.  You will be asked to enter an email address for the owner of this Site Collection. Enter the same email address you logged in with:

    ![](./README-Images/enterownerSPO.png)

5.  The OnePlace Solutions site template will then be downloaded and applied to your site collection:

    ![](./README-Images/applychanges.png)

    ![](./README-Images/applyingchangestosite.png)
