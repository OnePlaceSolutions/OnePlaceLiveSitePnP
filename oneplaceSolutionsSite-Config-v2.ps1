 <#
    This script creates a new Site collection (Team Site (Classic)), and applies the configuration changes for the OnePlace Solutions site.
#>

Try { 
    Set-ExecutionPolicy Bypass -Scope Process
    $tenant = Read-Host "Please enter the name of your Office 365 Tenant, eg for 'https://contoso.sharepoint.com/' just enter 'contoso'."
    $adminSharePoint = "https://$tenant-admin.sharepoint.com"
    $rootSharePoint = "https://$tenant.sharepoint.com"

    Connect-PnPOnline -Url $adminSharePoint -useweblogin

    $solutionsSite = Read-Host "Please enter the URL suffix for the Solutions Site you wish to provision, eg to create 'https://contoso.sharepoint.com/sites/oneplacesolutions', just enter 'oneplacesolutions'. Leave blank to use 'oneplacesolutions'."
    If($solutionsSite.Length -eq 0){
        $solutionsSite = 'oneplacesolutions'
    }
    $SolutionsSiteUrl = $rootSharePoint + '/sites/' + $solutionsSite
    $LicenseListUrl = $SolutionsSiteUrl + '/lists/Licenses'
    $ownerEmail = Read-Host "Please enter the email address of the owner for this site."

    Write-Host "Creating site with URL '$SolutionsSiteUrl', and owner '$ownerEmail'. Please wait..." -ForegroundColor Yellow

    New-PnPTenantSite -Title 'OnePlace Solutions Admin Site' -Url $SolutionsSiteUrl -Template STS#0 -Owner $ownerEmail -Timezone 0 -Wait
    
    Write-Host "`n`nSite created! Please authenticate against the newly created Site Collection`n" -ForegroundColor Green
    Start-Sleep -Seconds 3

    Connect-pnpOnline -url $SolutionsSiteUrl -UseWebLogin

    #Download OnePlace Solutions Site provisioning template   
    $WebClient = New-Object System.Net.WebClient   
    $Url = "https://raw.githubusercontent.com/OnePlaceSolutions/OnePlaceLiveSitePnP/master/oneplaceSolutionsSite-template-v1.xml"    
    $Path = "$env:temp\oneplaceSolutionsSite-template-v1.xml" 
    Write-Host "Downloading provisioning xml template to:" $Path -ForegroundColor Yellow  
    $WebClient.DownloadFile( $Url, $Path )

    #Download OnePlace Solutions Company logo to be used as Site logo    
    $UrlSiteImage = "https://raw.githubusercontent.com/OnePlaceSolutions/OnePlaceLiveSitePnP/master/oneplacesolutions-logo.png"
    $PathImage = "$env:temp\oneplacesolutions-logo.png" 
    $WebClient.DownloadFile( $UrlSiteImage, $PathImage )
       
    #Apply provisioning xml to new site collection
    Write-Host "Applying configuration changes..." -ForegroundColor Yellow
    Apply-PnPProvisioningTemplate -path $Path
    
    Write-Host "Provisioning complete!" -Green
    
    Write-Host "Creating License item in License List..." -ForegroundColor Yellow
    Add-PnPListItem -List "Licenses" -Values @{"Title" = "License"} -Verbose 
    $licenseItem = Get-PnPListItem -List "Licenses" -Query "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>License</Value></Eq></Where></Query></View>"
    
    If($null -ne $licenseItem){
        Write-Host "`nLicense Item created!" -ForegroundColor Green
    }
    
    Write-Host "`nPlease record the OnePlace Solutions Site URL and License Location / License List URL for usage in the OnePlaceMail Desktop and OnePlaceDocs clients:" -ForegroundColor Yellow
    Write-Host "-------------------" -ForegroundColor Red
    
    Write-Host "Solutions Site URL = $SolutionsSiteUrl"
    Write-Host "License List URL = $LicenseListUrl"
    
    Write-Host "-------------------" -ForegroundColor Red
    Write-Host "Opening Solutions Site at $SolutionsSiteUrl..." -ForegroundColor Yellow
    Pause
    Start $SolutionsSiteUrl
}

Catch {
    write-host "Caught an exception:" -ForegroundColor Red
    write-host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
}
