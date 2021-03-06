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

## Manually create a SharePoint Site Collection
### On-Premise
In Central Administration, create a site collection based on the Team Site template

![](./README-Images/createsitecollection-onpremise-v2.png)

### SharePoint Online
In SharePoint Administration in your tenant, create a site collection based on the Team Site template:

![](./README-Images/createsitecollection-online.png)

## Apply the OnePlace Solutions Site configurations to your site collection

1.  Start PowerShell on your machine:

    ![](./README-Images/image4.png)

2.  Copy and paste the following command into your PowerShell command
    window and hit enter:

    ```PowerShell
    Invoke-Expression (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/OnePlaceSolutions/OnePlaceLiveSitePnP/master/oneplaceSolutionsSite-Config-v1.ps1')
    ```

    ![](./README-Images/ps1command.png)


3.  The PowerShell script will execute and prompt you to enter the Site Collection Url of the site collection you manually created in the earlier step. You can either type it in or copy and paste the url into the command window and hit enter:

    ![](./README-Images/enterurl.png)

4.  You will be asked to enter your credentials for SharePoint. For SharePoint Online it will be your email address, for on-premise it will be your domain\\username:

    ![](./README-Images/credentials.png)

5.  The OnePlace Solutions site template will then be downloaded and applied to your site collection:

    ![](./README-Images/applychanges.png)

    ![](./README-Images/applyingchangestosite.png)
