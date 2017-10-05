 <#
        This script prompt creates a new site collection in your Office 365 tenant
        The user is prompted for the SharePoint Site Collection url, Site Owner and TimeZone of the newly created
        Site Collection  
#>

try {    
    Set-ExecutionPolicy Bypass -Scope Process

    #Prompt for SharePoint Url     
    $SharePointUrl = Read-Host -Prompt 'Enter the url of your new OnePlaceLive Site Collection'

    #Prompt for SharePoint Site Owner (email address)    
    $SiteOwner = Read-Host -Prompt 'Enter the site owner of your new OnePlaceLive Site Collection'

    #Prompt for timezone of newly created site collection (enter id number)
    #Get-PnPTimeZoneId | Out-Host
    #$TZone = Read-Host -Prompt 'Choose timezone id based on values above'

    #Create site collection based on team site template
    New-PnPTenantSite -Owner $SiteOwner -Title 'OnePlace Solutions Live Site' -Url $SharePointUrl -Template 'STS#0' -TimeZone 4

    #Connect to newly created site collection
    Connect-pnpOnline -url $SharePointUrl

    #Download OnePlaceLive site provisioning template
    Write-Host "Downloading provisioning xml template:" $Path -ForegroundColor Green 
    Set-ExecutionPolicy Bypass -Scope Process
    $WebClient = New-Object System.Net.WebClient   
    $Url = "https://raw.githubusercontent.com/OnePlaceSolutions/OnePlaceLiveSitePnP/master/livesitepnp-template.xml"    
    $Path = "$env:temp\livesitepnp-template.xml"
    
    $WebClient.DownloadFile( $Url, $Path )   

    #Apply provisioning xml to new site collection
    Apply-PnPProvisioningTemplate -path $Path
   
}
catch {
    Write-Host $error[0].Message
}
