Pre-requisites
--------------

1.  SharePoint Online, SharePoint 2016 on-premise, SharePoint 2013
    on-premise.

2.  PowerShell v3.0 or greater installed on the machine. Windows 10/8.1
    and Windows Server 2012 and greater are all ready to go. Windows 7
    is preinstalled with v2.0 of PowerShell. PowerShell needs to be
    upgraded on Windows 7 machines. This can be done by downloading and
    installing the Windows Management Framework 4.0 from here:
    <https://www.microsoft.com/en-au/download/details.aspx?id=40855> .
    Download and install either the x64 or x86 version based on your
    version of Windows 7:

    ![](./README-Images/image1.png)

3.  Install the SharePoint PnP PowerShell cmdlets installed on the
    machine. You need to install the correct version of the cmdlets to
    target your version of SharePoint. Install the latest release msi
    files from here (new updates are applied monthly to the msi files):
    <https://github.com/SharePoint/PnP-PowerShell/releases>.

You will need to logon as a local Administrator to your machine to
install the msi file:

![](./README-Images/image2.png)

![](./README-Images/image3.png)


Manually create a SharePoint Site Collection
--------------------------------------------

On-Premise - Go to Central Administration and create a site collection based on the Team Site template:
![](./README-Images/createsitecollection-onpremise.png)

SharePoint Online - Go to SharePoint Administration in your tenant and create a site collection based on the Team Site template:

Applying the OnePlace Solution Site configurations to your site collection
--------------------------------------

1.  Start PowerShell on your machine:

    ![](./README-Images/image4.png)

2.  Copy and paste the following command into your PowerShell command
    window and hit enter:

> **Invoke-Expression (New-Object
> Net.WebClient).DownloadString(‘https://raw.githubusercontent.com/OnePlaceSolutions/EmailColumnsPnP/master/.ps1’)**
>
> Copy the text above, then in the PowerShell window right click at the
> cursor and the command will be pasted into the window, then hit the
> enter key to execute the command:

![](./README-Images/image5.png)

3.  The PowerShell script will execute and prompt you to enter the Site
    Collection Url for the Site Collection you wish to deploy the Email
    columns to. You can either type it in or copy and paste the url into
    the command window and hit enter:

    ![](./README-Images/image6.png)

    ![](./README-Images/image7.png)

4.  You will be asked to enter your credentials for SharePoint. For
    SharePoint Online it will be your email address, for on-premise it
    will your domain\\username:

    ![](./README-Images/image8.png)

5.  The email columns template will then be downloaded and applied to
    your site collection:

    ![](./README-Images/image9.png)

    ![](./README-Images/image10.png)
