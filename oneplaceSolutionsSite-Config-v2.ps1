 <#
    This script creates a new Site collection (Team Site (Classic)), and applies the configuration changes for the OnePlace Solutions site.
#>
$ErrorActionPreference = 'Stop'
$script:logPath = "$env:userprofile\Documents\OPSScriptLog.txt"
function Write-Log { 
    <#
    .NOTES 
        Created by: Jason Wasser @wasserja 
        Modified by: Ashley Gregory
    .LINK (original)
        https://gallery.technet.microsoft.com/scriptcenter/Write-Log-PowerShell-999c32d0 
    #>
    [CmdletBinding()] 
    Param ( 
        [Parameter(Mandatory=$true, 
                   ValueFromPipelineByPropertyName=$true)] 
        [ValidateNotNullOrEmpty()] 
        [Alias("LogContent")] 
        [string]$Message, 
 
        [Parameter(Mandatory=$false)] 
        [Alias('LogPath')] 
        [string]$Path = $script:logPath, 
         
        [Parameter(Mandatory=$false)] 
        [ValidateSet("Error","Warn","Info")] 
        [string]$Level = "Info", 
         
        [Parameter(Mandatory=$false)] 
        [switch]$NoClobber 
    ) 
 
    Begin{
        $VerbosePreference = 'SilentlyContinue' 
        $ErrorActionPreference = 'Continue'
    } 
    Process{
        # If the file already exists and NoClobber was specified, do not write to the log. 
        if((Test-Path $Path) -AND $NoClobber){ 
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name." 
            Return 
        } 
 
        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path. 
        elseif(!(Test-Path $Path)){ 
            Write-Verbose "Creating $Path." 
            $NewLogFile = New-Item $Path -Force -ItemType File 
        } 
 
        else{ 
            # Nothing to see here yet. 
        } 
 
        # Format Date for our Log File 
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss" 
 
        # Write message to error, warning, or verbose pipeline and specify $LevelText 
        switch($Level){ 
            'Error'{ 
                Write-Error $Message 
                $LevelText = 'ERROR:' 
             } 
            'Warn'{ 
                Write-Warning $Message 
                $LevelText = 'WARNING:' 
             } 
            'Info'{ 
                Write-Verbose $Message 
                $LevelText = 'INFO:' 
             } 
        } 
         
        # Write log entry to $Path 
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append 
    }
    End{
        $ErrorActionPreference = 'Stop'
    } 
}

Try { 
    Set-ExecutionPolicy Bypass -Scope Process
    $tenant = Read-Host "Please enter the name of your Office 365 Tenant, eg for 'https://contoso.sharepoint.com/' just enter 'contoso'."
    $adminSharePoint = "https://$tenant-admin.sharepoint.com"
    $rootSharePoint = "https://$tenant.sharepoint.com"

    Write-Log -Level Info -Message "Tenant set to $tenant"
    Write-Log -Level Info -Message "Admin SharePoint set to $adminSharePoint"
    Write-Log -Level Info -Message "Root SharePoint set to $rootSharePoint"

    Connect-PnPOnline -Url $adminSharePoint -useweblogin

    $solutionsSite = Read-Host "Please enter the URL suffix for the Solutions Site you wish to provision, eg to create 'https://contoso.sharepoint.com/sites/oneplacesolutions', just enter 'oneplacesolutions'. Leave blank to use 'oneplacesolutions'."
    If($solutionsSite.Length -eq 0){
        Write-Log -Level Warnn -Message "No URL suffix entered, defaulting to 'oneplacesolutions'"
        $solutionsSite = 'oneplacesolutions'
    }
    Write-Log -Level Info -Message "Solutions Site URL suffix set to $solutionsSite"

    $SolutionsSiteUrl = $rootSharePoint + '/sites/' + $solutionsSite
    $LicenseListUrl = $SolutionsSiteUrl + '/lists/Licenses'
    $ownerEmail = Read-Host "Please enter the email address of the owner for this site."

    $filler = "Creating site with URL '$SolutionsSiteUrl', and owner '$ownerEmail'. Please wait..."
    Write-Host $filler -ForegroundColor Yellow
    Write-Log -Level Info -Message $filler
    $timeStartCreate = Get-Date
    New-PnPTenantSite -Title 'OnePlace Solutions Admin Site' -Url $SolutionsSiteUrl -Template STS#0 -Owner $ownerEmail -Timezone 0 -Wait
    $timeEndCreate = Get-Date
    $timeToCreate = New-TimeSpan -Start $timeStartCreate -End $timeEndCreate
    Write-Host "`n`nSite created! Please authenticate against the newly created Site Collection`n" -ForegroundColor Green
    Write-Log -Level Info -Message "Site Created. Took $timeToCreate"
    Start-Sleep -Seconds 3

    Connect-pnpOnline -url $SolutionsSiteUrl -UseWebLogin

    #Download OnePlace Solutions Site provisioning template
    $WebClient = New-Object System.Net.WebClient   
    $Url = "https://raw.githubusercontent.com/OnePlaceSolutions/OnePlaceLiveSitePnP/master/oneplaceSolutionsSite-template-v1.xml"    
    $Path = "$env:temp\oneplaceSolutionsSite-template-v1.xml" 

    $filler = "Downloading provisioning xml template to: $Path"
    Write-Host $filler -ForegroundColor Yellow  
    Write-Log -Level Info -Message $filler
    $WebClient.DownloadFile( $Url, $Path )

    #Download OnePlace Solutions Company logo to be used as Site logo    
    $UrlSiteImage = "https://raw.githubusercontent.com/OnePlaceSolutions/OnePlaceLiveSitePnP/master/oneplacesolutions-logo.png"
    $PathImage = "$env:temp\oneplacesolutions-logo.png" 
    $WebClient.DownloadFile( $UrlSiteImage, $PathImage )
    Write-Log -Level Info -Message "Downloading OPS logo for Solutions Site"
       
    #Apply provisioning xml to new site collection
    $filler = "Applying configuration changes..."
    Write-Host $filler -ForegroundColor Yellow
    Write-Log -Level Info -Message $filler

    Apply-PnPProvisioningTemplate -path $Path
    
    $filler = "Provisioning complete!"
    Write-Host $filler -ForeGroundColor Green
    Write-Log -Level Info -Message $filler

    $filler = "Creating License item in License List..."
    Write-Host $filler -ForegroundColor Yellow
    Write-Log -Level Info -Message $filler
    Add-PnPListItem -List "Licenses" -Values @{"Title" = "License"} 
    $licenseItem = Get-PnPListItem -List "Licenses" -Query "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>License</Value></Eq></Where></Query></View>"
    $licenseListId = ((Get-PnPList -Identity "Licenses").Id).ToString()

    If($null -ne $licenseItem){
        $filler = "License Item created!"
        Write-Host "`n$filler" -ForegroundColor Green
        Write-Log -Level Info -Message $filler
    }
    Else{
        $filler = "License Item was not created"
        Write-Host "`n$filler" -ForegroundColor Red
        Write-Log -Level Error -Message $filler
    }
    
    Write-Log -Level Info -Message "Solutions Site URL = $SolutionsSiteUrl"
    Write-Log -Level Info -Message "License List URL = $LicenseListUrl"
    Write-Log -Level Info -Message "License List ID = $licenseListId"

    Write-Host "`nPlease record the OnePlace Solutions Site URL and License Location / License List URL for usage in the OnePlaceMail Desktop and OnePlaceDocs clients, and the License List Id for the licensing process. `nThese have also been written to a log file at '$script:logPath'" -ForegroundColor Yellow
    Write-Host "-------------------" -ForegroundColor Red
    
    Write-Host "Solutions Site URL = $SolutionsSiteUrl"
    Write-Host "License List URL = $LicenseListUrl"
    Write-Host "License List Id = $licenseListId"
    
    Write-Host "-------------------" -ForegroundColor Red
    Write-Host "Opening Solutions Site at $SolutionsSiteUrl..." -ForegroundColor Yellow

    Pause
    Start $SolutionsSiteUrl
}

Catch {
    $exType = $($_.Exception.GetType().FullName)
    $exMessage = $($_.Exception.Message)
    write-host "Caught an exception:" -ForegroundColor Red
    write-host "Exception Type: $exType" -ForegroundColor Red
    write-host "Exception Message: $exMessage" -ForegroundColor Red
    Write-Log -Level Error -Message "Caught an exception. Exception Type: $exType"
    Write-Log -Level Error -Message $exMessage
}
