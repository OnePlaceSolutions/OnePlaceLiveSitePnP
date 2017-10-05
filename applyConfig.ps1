 <#
        This script prompt creates a new site collection in your Office 365 tenant
        The user is prompted for the SharePoint Site Collection url, Site Owner and TimeZone of the newly created
        Site Collection  
#>

try {    
    Set-ExecutionPolicy Bypass -Scope Process

    #Prompt for SharePoint Url     
    $SharePointUrl = Read-Host -Prompt 'Enter the url of your OnePlaceLive Site Collection'
        
    #Connect to newly created site collection
    Connect-pnpOnline -url $SharePointUrl    

    #Download OnePlaceLive site provisioning template
    Write-Host "Downloading provisioning xml template:" $Path -ForegroundColor Green
    $WebClient = New-Object System.Net.WebClient   
    $Url = "https://raw.githubusercontent.com/OnePlaceSolutions/OnePlaceLiveSitePnP/master/livesitepnp-template.xml"    
    $Path = "$env:temp\livesitepnp-template.xml"   
    $WebClient.DownloadFile( $Url, $Path )   
    
    #Apply provisioning xml to new site collection
    Write-Host "Applying configuration changes..." -ForegroundColor Green
    Apply-PnPProvisioningTemplate -path $Path    

}
catch {
    Write-Host $error[0].Message
}
