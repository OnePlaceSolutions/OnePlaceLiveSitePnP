 <#
        This script prompt creates a new site collection in your Office 365 tenant
        The user is prompted for the SharePoint Site Collection url, Site Owner and TimeZone of the newly created
        Site Collection  
#>

try {    
    Set-ExecutionPolicy Bypass -Scope Process

   
    Write-Host "Downloading provisioning xml template:" $Path -ForegroundColor Green 
    #Download OnePlaceLive site provisioning template
    $WebClient = New-Object System.Net.WebClient   
    $Url = "https://raw.githubusercontent.com/OnePlaceSolutions/OnePlaceLiveSitePnP/master/livesitepnp-template.xml"    
    $Path = "$env:temp\livesitepnp-template.xml"

    Write-Host "Downloading provisioning xml template:" $Path -ForegroundColor Green 
    $WebClient.DownloadFile( $Url, $Path )   

}
catch {
    Write-Host $error[0].Message
}
