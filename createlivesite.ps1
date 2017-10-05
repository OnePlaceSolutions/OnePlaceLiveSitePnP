 <#
        This script prompts you to install the SharePoint PnP commands. Hit enter for SharePoint Online,
        6 for SharePoint 2016,3 for SharePoint 2013
        The script then prompts for the site collectiuon url you wish to install the Email Columns to
        and then applies the email columns template to this site collection        
#>

try {    
    Set-ExecutionPolicy Bypass -Scope Process

    #Prompt for SharePoint Url     
    $SharePointUrl = Read-Host -Prompt 'Enter the url of your new OnePlaceLive Site Collection'

    #Prompt for SharePoint Site Owner (email address)    
    $SiteOwner = Read-Host -Prompt 'Enter the site owner of your new OnePlaceLive Site Collection'

    #Prompt for timezone of newly created site collection (enter id number)
    Get-PnPTimeZone
    $TZone = Read-Host -Prompt 'Choose timezone id based on values above'

    #Create site collection based on team site template
    New-PnPTenantSite -Owner $SiteOwner -Title 'OnePlace Solutions Live Site' -Url $SharePointUrl -Template 'STS#0' -TimeZone $TZone

    #Connect to newly created site collection
    Connect-pnpOnline -url $SharePointUrl

    #Download OnePlaceLive site provisioning template
    $WebClient = New-Object System.Net.WebClient   
    $Url = "https://raw.githubusercontent.com/OnePlaceSolutions/OnePlaceLiveSitePnP/master/livesitepnp-template.xml"    
    $Path = "$env:temp\livesitepnp-template.xml"

    Write-Host "Downloading provisioning xml template:" $Path -ForegroundColor Green 
    $WebClient.DownloadFile( $Url, $Path )   

    #Apply provisioning xml to new site collection
    Apply-PnPProvisioningTemplate -path $Path
   
}
catch {
    Write-Host $error[0].Message
}
