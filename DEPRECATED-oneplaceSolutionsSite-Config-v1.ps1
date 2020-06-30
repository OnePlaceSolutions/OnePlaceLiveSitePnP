 <#
        This script applies the configuration changes for the OnePlace Solutions site to an existing site collection.
        A new site collection based on the Team Site template should be created manually before running this script.
#>

try {    
    Set-ExecutionPolicy Bypass -Scope Process

    #Prompt for SharePoint URL     
    $SharePointUrl = Read-Host -Prompt 'Enter the URL of your OnePlace Solutions Site'
        
    #Connect to newly created site collection
    If($SharePointUrl -match ".sharepoint.com/"){
        Write-Host "Enter SharePoint credentials (your email address for SharePoint Online):" -ForegroundColor Green  
        Connect-pnpOnline -url $SharePointUrl -UseWebLogin
    }
    Else{
        Write-Host "Enter SharePoint credentials (domain\username for on-premises):" -ForegroundColor Green  
        Connect-pnpOnline -url $SharePointUrl
    }

    #Download OnePlace Solutions Site provisioning template   
    $WebClient = New-Object System.Net.WebClient   
    $Url = "https://raw.githubusercontent.com/OnePlaceSolutions/OnePlaceLiveSitePnP/master/oneplaceSolutionsSite-template-v1.xml"    
    $Path = "$env:temp\oneplaceSolutionsSite-template-v1.xml" 
    Write-Host "Downloading provisioning xml template:" $Path -ForegroundColor Green  
    $WebClient.DownloadFile( $Url, $Path ) 

    #Download OnePlace Solutions Company logo to be used as Site logo    
    $UrlSiteImage = "https://raw.githubusercontent.com/OnePlaceSolutions/OnePlaceLiveSitePnP/master/oneplacesolutions-logo.png"
    $PathImage = "$env:temp\oneplacesolutions-logo.png" 
    $WebClient.DownloadFile( $UrlSiteImage, $PathImage )  
       
    #Apply provisioning xml to new site collection
    Write-Host "Applying configuration changes..." -ForegroundColor Green
    Apply-PnPProvisioningTemplate -path $Path
}

catch {
  write-host "Caught an exception:" -ForegroundColor Red
  write-host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
  write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
}
