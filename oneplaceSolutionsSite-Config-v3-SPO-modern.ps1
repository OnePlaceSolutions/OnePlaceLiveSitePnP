﻿Param ([String]$solutionsSite = 'oneplacesolutions')
<#
    This script optionally creates a new Site collection ('Team Site (Modern)' by default, 'Team Site (Classic)' by option), and applies the configuration changes / PnP template for the OnePlace Solutions site.
    All major actions are logged to 'OPSScriptLog.txt' in the user's or Administrators Documents folder, and it is uploaded to the Solutions Site at the end of provisioning.
#>
$ErrorActionPreference = 'Stop'
$script:logFile = "OPSScriptLog.txt"
$script:logPath = "$env:userprofile\Documents\$script:logFile"

#Set this to $true to use only the PnP auth, set to $false to use SharePoint Online Management Shell auth. Deploying to an existing Site will try to only use PnP.
#Default: $false
$script:onlyPnP = $false

#Assume we are creating a new Site Collection from scratch
#Default: $true
$script:doSiteCreation = $true

#Set this to $false to create and/or provision to a classic site and template (v2 SPO) instead of a modern site and template (v3 SPO)
#Default: $true
$script:doModern = $true

$pnp = Get-Module SharePointPnPPowerShell* | Select-Object Name, Version
$spoms = Get-InstalledModule Microsoft.Online.SharePoint.PowerShell | Select-Object Name, Version

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
        [Parameter(Mandatory = $true, 
            ValueFromPipelineByPropertyName = $true)] 
        [ValidateNotNullOrEmpty()] 
        [Alias("LogContent")] 
        [string]$Message, 
 
        [Parameter(Mandatory = $false)] 
        [Alias('LogPath')] 
        [string]$Path = $script:logPath, 
         
        [Parameter(Mandatory = $false)] 
        [ValidateSet("Error", "Warn", "Info")] 
        [string]$Level = "Info", 
         
        [Parameter(Mandatory = $false)] 
        [switch]$NoClobber 
    ) 
 
    Begin {
        $VerbosePreference = 'SilentlyContinue' 
        $ErrorActionPreference = 'Continue'
    } 
    Process {
        # If the file already exists and NoClobber was specified, do not write to the log. 
        If ((Test-Path $Path) -AND $NoClobber) { 
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name." 
            Return 
        } 
 
        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path. 
        ElseIf (!(Test-Path $Path)) { 
            Write-Verbose "Creating $Path." 
            $NewLogFile = New-Item $Path -Force -ItemType File 
        } 
 
        Else { 
            # Nothing to see here yet. 
        } 
 
        # Format Date for our Log File 
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss K" 
 
        # Write message to error, warning, or verbose pipeline and specify $LevelText 
        Switch ($Level) { 
            'Error' { 
                Write-Error $Message 
                $LevelText = 'ERROR:' 
            } 
            'Warn' { 
                Write-Warning $Message 
                $LevelText = 'WARNING:' 
            } 
            'Info' { 
                Write-Verbose $Message 
                $LevelText = 'INFO:' 
            } 
        } 
         
        # Write log entry to $Path 
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append 
    }
    End {
        $ErrorActionPreference = 'Stop'
    } 
}

Clear-Host 
Write-Host "`n--------------------------------------------------------------------------------`n" -ForegroundColor Red
Write-Host 'Welcome to the Solutions Site Deployment Script for OnePlace Solutions' -ForegroundColor Green
Write-Host "`n--------------------------------------------------------------------------------`n" -ForegroundColor Red
Get-InstalledModule *Sharepoint* | Out-Null
Write-Host "Please ensure you have checked and installed the pre-requisites listed in the GitHub documentation prior to continuing this script."
Write-Host "!!! If pre-requisites for the Solutions Site creation/provisioning have not been completed this process may fail !!!" -ForegroundColor Yellow
Start-Sleep -Seconds 2
Pause

Write-Log -Level Info -Message "PnP Installed: $pnp"
Write-Log -Level Info -Message "SPOMS Installed: $spoms"

Write-Host "Beginning script. Logging script actions to $script:logPath" -ForegroundColor Cyan
Start-Sleep -Seconds 3
#First Try statement is to set the execution policy
Try {
    Set-ExecutionPolicy Bypass -Scope Process

    #Second Try statement is to house the script content
    Try {
        
        function Send-OutlookEmail ($attachment, $body) {
            Try {
                #create COM object named Outlook
                $Outlook = New-Object -ComObject Outlook.Application
                #create Outlook MailItem named Mail using CreateItem() method
                $Mail = $Outlook.CreateItem(0)
                #add properties as desired
                $Mail.To = "success@oneplacesolutions.com"
                $Mail.CC = "support@oneplacesolutions.com"
                $from = $Outlook.Session.CurrentUser.Name
                $Mail.Subject = "Solutions Site and License List Information generated by $from"
                $Mail.Body = "Hello Customer Success Team`n`nPlease find our Solutions Site and License List details below:`n`n$body"
    
                $mail.Attachments.Add($attachment) | Out-Null
                Write-Host "Please open the new email being composed in Outlook, add information as necessary, and send it to the address indicated (success@oneplacesolutions.com)" -ForegroundColor Yellow
                $mail.Display()
                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($Outlook) | Out-Null
            }
            Catch {
                Write-Host "Failed to open a new email in Outlook." -ForegroundColor Red
                Write-Log -Level Error -Message $_
            }
        }
    
        function Attempt-Provision ([int]$count) {
            #Our first provisioning run can encounter a 403 if SharePoint has incorrectly told us the site is ready, this function will retry 
            Try {
                Apply-PnPProvisioningTemplate -path $Script:TemplatePath -ExcludeHandlers Pages, SiteSecurity -ClearNavigation
                Apply-PnPProvisioningTemplate -Path $Script:TemplatePath -Handlers Lists -ErrorAction Ignore
            }
            Catch [System.Net.WebException] {
                If ($($_.Exception.Message) -match '(403)') {
                    #SPO returning a trigger happy ready response, sleep for a bit...
                    $filler = "SharePoint Online incorrectly indicated the site is ready to provision, pausing the script to wait for it to catch up. Retrying in 5 minutes. Retry $count/4"
                    Write-Host $filler -ForegroundColor Yellow
                    Write-Log -Level Info -Message $filler

                    If ($count -lt 4) {
                        Start-Sleep -Seconds 300
                        $count = $count + 1
                        Attempt-Provision -count $count
                    }
                    Else {
                        $filler = "SharePoint Online is taking an unusual amount of time to create the site. Please check your SharePoint Admin Site in Office 365, and when the site is created please continue the script. Do not press Enter until you have confirmed the site has been completely created."
                        Write-Host $filler -ForegroundColor Red
                        Write-Log -Level Info -Message $filler
                        Write-Host "`n"
                        Pause
                        Apply-PnPProvisioningTemplate -Path $Script:templatePath -ExcludeHandlers Pages, SiteSecurity -ClearNavigation
                        Apply-PnPProvisioningTemplate -Path $Script:TemplatePath -Handlers Lists -ErrorAction Ignore
                    }
                }
                Else {
                    Throw $_.Exception.Message
                }
            }
            Catch [System.Management.Automation.RuntimeException] {
                If((Get-PnPProperty -ClientObject (Get-PnPWeb) -Property WebTemplate) -eq 'GROUP'){
                    Write-Log -Level Warn -Message "GROUP#0 Site, non terminating error, continuing."
                }
                Else {
                    Throw $_.Exception.Message
                }
            }
            Catch {
                Throw $_.Exception.Message
            }
        }

        function Deploy() {
            Write-Log -Level Info -Message "Creating Site from scratch? $script:doSiteCreation"
            Write-Log -Level Info -Message "Are we only using PnP? $script:onlyPnP"
            
            #Stage 1a Continuing with creating a Solutions Site from scratch
            If($script:doSiteCreation) {
                $stage = "Stage 1/3 - Team Site (Modern) creation"
                Write-Host "`n$stage`n" -ForegroundColor Yellow
                Write-Progress -Activity "Solutions Site Deployment" -CurrentOperation $stage -PercentComplete (33)
                
                $rootSharePoint = Read-Host "Please enter your SharePoint Online Root Site Collection URL, eg 'https://contoso.sharepoint.com/'"
                $rootSharePoint.Trim()

                $tenant = $rootSharepoint  -match 'https://(?<Tenant>.+)\.sharepoint.com'
                $tenant = $Matches.Tenant

                $adminSharePoint = "https://$tenant-admin.sharepoint.com"

                If (($rootSharePoint.Length -eq 0) -or ($tenant.Length -eq 0)) {
                    Write-Host "Root SharePoint URL invalid. Exiting script."
                    Write-Log -Level Error -Message "No tenant entered. Exiting script."
                    Exit
                }

                Try {
                    If ($script:onlyPnP) {
                        Connect-PnPOnline -Url $adminSharePoint -UseWebLogin
                    }
                    Else {
                        Connect-PnPOnline -Url $adminSharePoint -SPOManagementShell
                        Write-Host "Prompting for SharePoint Online Management Shell Authentication. Please do not continue until you are logged in. If no prompt appears you may already be authenticated to this Tenant."
                        Start-Sleep -Seconds 5
                        #PnP doesn't wait for SPO Management Shell to complete it's login, have to pause here
                        Pause
                        #See if we can get the current web, throw an exception otherwise so we don't continue without being connected
                        Get-PnPWeb | Out-Null
                    }
                }
                Catch {
                    $exMessage = $($_.Exception.Message)
                    If ($exMessage -match "(403)") {
                        Write-Log -Level Error -Message $exMessage
                        $filler = "Error connecting to '$adminSharePoint'. Please ensure you have sufficient rights to create Site Collections in your Microsoft 365 Tenant. `nThis usually requires Global Administrative rights, or alternatively ask your SharePoint Administrator to perform the Solutions Site Setup."
                        Write-Host $filler -ForegroundColor Yellow
                        Write-Host "Please contact OnePlace Solutions Support if you are still encountering difficulties."
                        Write-Log -Level Info -Message $filler
                        
                    }
                    Throw $_.Exception.Message
                }

                Write-Log -Level Info -Message "Tenant set to $tenant"
                Write-Log -Level Info -Message "Admin SharePoint set to $adminSharePoint"
                Write-Log -Level Info -Message "Root SharePoint set to $rootSharePoint"

                $solutionsSite = $solutionsSite.Trim()
                If ($solutionsSite.Length -eq 0) {
                    $solutionsSite = Read-Host "Please enter the URL suffix for the Solutions Site you wish to provision, eg to create 'https://contoso.sharepoint.com/sites/oneplacesolutions', just enter 'oneplacesolutions'."
                    $solutionsSite = $solutionsSite.Trim()
                    If ($solutionsSite.Length -eq 0) {
                        Write-Host "Can't have an empty URL. Exiting script"
                        Write-Log -Level Error -Message "No URL suffix entered. Exiting script."
                        Exit
                    }
                }
                Write-Log -Level Info -Message "Solutions Site URL suffix set to $solutionsSite"

                $SolutionsSiteUrl = $rootSharePoint + '/sites/' + $solutionsSite
                $LicenseListUrl = $SolutionsSiteUrl + '/lists/Licenses'

                Try {
                    $ownerEmail = Read-Host "Please enter the email address of the owner-to-be for this site. This should be your current credentials."
                    $ownerEmail = $ownerEmail.Trim()
                    If ($ownerEmail.Length -eq 0) {
                        $filler = 'No Site Collection owner has been entered. Exiting script.'
                        Write-Host $filler
                        Write-Log -Level Error -Message $filler
                        Exit
                    }
                    #Creating the site collection
                    $filler = "Creating site collection with URL '$SolutionsSiteUrl' for the Solutions Site, and owner '$ownerEmail'. This may take a while, please do not close this window, but feel free to minimize the PowerShell window and check back in 10 minutes."
                    Write-Host $filler -ForegroundColor Yellow
                    Write-Log -Level Info -Message $filler

                    $timeStartCreate = Get-Date
                    $filler = "Starting site creation at $timeStartCreate...."
                    Write-Host $filler -ForegroundColor Yellow
                    Write-Log -Level Info -Message $filler
                
                    If ($script:doModern) {
                        New-PnPTenantSite -Title 'OnePlace Solutions Admin Site' -Url $SolutionsSiteUrl -Template STS#3 -Owner $ownerEmail -Timezone 0 -StorageQuota 110 -Wait
                    }
                    Else {
                        New-PnPTenantSite -Title 'OnePlace Solutions Admin Site' -Url $SolutionsSiteUrl -Template STS#0 -Owner $ownerEmail -Timezone 0 -StorageQuota 110 -Wait
                    }

                    $timeEndCreate = Get-Date
                    $timeToCreate = New-TimeSpan -Start $timeStartCreate -End $timeEndCreate
                    $filler = "Site Created. Finished at $timeEndCreate. Took $timeToCreate"
                    Write-Host "`n"
                    Write-Host $filler "`n" -ForegroundColor Green
                    Write-Log -Level Info -Message $filler
                }
                Catch [Microsoft.SharePoint.Client.ServerException] {
                    $exMessage = $($_.Exception.Message)
                    If ($exMessage -match 'A site already exists at url') {
                        Write-Host $exMessage -ForegroundColor Red
                        Write-Log -Level Error -Message $exMessage
                        Write-Host "Site with URL $SolutionsSiteUrl already exists. Please run the script again and choose a different Solutions Site suffix, or opt to deploy to an existing Site." -ForegroundColor Red
                        Throw $_.Exception.Message
                    }
                    ElseIf (($exMessage -match '401') -and (-not $script:onlyPnP)) {
                        $filler = "Auth issue with SharePoint Online Management Shell. Re-run script with '`$script:onlyPnP' flag set to `$true. `nIf the Solutions Site does show in your SharePoint Online admin center, re-run the script and opt to deploy to an existing site."
                        Write-Log -Level Error -Message $filler
                    }
                    Else {
                        Throw $_.Exception.Message
                    }
                }
                Catch {
                    Write-Log -level Info -Message "Something went wrong during Site Creation. Details following"
                    Throw $_.Exception.Message
                }
                
            }
            #Stage 1b Skipping Site Creation, identifying Solutions Site instead
            Else {
                $stage = "Stage 1/3 - Identify Solutions Site"
                Write-Host "`n$stage`n" -ForegroundColor Yellow
                Write-Progress -Activity "Solutions Site Deployment" -CurrentOperation $stage -PercentComplete (33)
                
                $input = Read-Host "What is the URL of the existing Site Collection? Eg, 'https://contoso.sharepoint.com/sites/oneplacesolutions'. Do not include trailing view information such as '/AllItems.aspx'."
                $input = $input.Trim()
                If($input.Length -ne 0){
                    $solutionsSiteUrl = $input.TrimEnd('/')
                }
                Else {
                    Write-Host "Can't have an empty URL. Exiting script"
                    Write-Log -Level Error -Message "No Solutions Site URL  entered. Exiting script."
                    Exit
                }
                $LicenseListUrl = $SolutionsSiteUrl + '/lists/Licenses'
            }

            #Stage 2 Applying the template
            Try {
                $stage = "Stage 2/3 - Apply Solutions Site template"
                Write-Host "`n$stage`n" -ForegroundColor Yellow
                Write-Progress -Activity "Solutions Site Deployment" -CurrentOperation $stage -PercentComplete (66)

                #Connecting to the site collection to apply the template
                If ($script:onlyPnP) {
                    Write-Host  "Please authenticate against the Site Collection"
                    Start-Sleep -Seconds 3
                    Connect-PnPOnline -Url $SolutionsSiteUrl -UseWebLogin
                }
                Else {
                    Write-Host "Attempting to use existing SPO Management Shell Authentication..."
                    Connect-PnPOnline -Url $SolutionsSiteUrl -SPOManagementShell
                    #PnP doesn't wait for SPO Management Shell to complete it's login, have to pause here
                    Start-Sleep -Seconds 5
                    Pause
                }

                If ($script:doModern) {
                    $Url = "https://raw.githubusercontent.com/OnePlaceSolutions/OnePlaceLiveSitePnP/master/oneplaceSolutionsSite-template-v3-modern.xml"    
                    $Script:templatePath = "$env:temp\oneplaceSolutionsSite-template-v3-modern.xml" 
                }
                Else {
                    $Url = "https://raw.githubusercontent.com/OnePlaceSolutions/OnePlaceLiveSitePnP/master/oneplaceSolutionsSite-template-v2.xml"    
                    $Script:templatePath = "$env:temp\oneplaceSolutionsSite-template-v2.xml" 
                }

                $UrlSiteImage = "https://raw.githubusercontent.com/OnePlaceSolutions/OnePlaceLiveSitePnP/master/oneplacesolutions-logo.png"
                $PathImage = "$env:temp\oneplacesolutions-logo.png" 

                #Check if resources already exist
                If((-not (Test-Path $Script:templatePath -NewerThan (Get-Date).AddDays(-7))) -or (-not (Test-Path $PathImage))) {
                    Write-Log -Level Info -Message 'Local resources not present or older than 7 days.'
                    #Download OnePlace Solutions Site provisioning template
                    $WebClient = New-Object System.Net.WebClient
                    $filler = "Downloading provisioning xml template to: $Script:templatePath"
                    Write-Host $filler -ForegroundColor Yellow  
                    Write-Log -Level Info -Message $filler
                    $WebClient.DownloadFile( $Url, $Script:TemplatePath )
        
                    #Download OnePlace Solutions Company logo to be used as Site logo    
                    $WebClient.DownloadFile( $UrlSiteImage, $PathImage )
                    Write-Log -Level Info -Message "Downloading OPS logo for Solutions Site"
                }
                Else {
                    Write-Log -Level Info -Message 'Local resources present, skipping download.' -Verbose
                }

                #Apply provisioning xml to new site collection
                $filler = "Applying configuration changes..."
                Write-Host $filler -ForegroundColor Yellow
                Write-Log -Level Info -Message $filler

                Attempt-Provision -count 0

                Write-Log -Level Info -Message "Templated applied without SiteSecurity, Pages"

                Write-Log -Level Info -Message "Retrieving License List ID"
                $licenseList = Get-PnPList -Identity "Licenses"
                $licenseListId = $licenseList.ID
                $licenseListId = $licenseListId.ToString()
                Write-Log -Level Info -Message "License List ID retrieved: $licenseListId"

                $filler = "Applying Site Security and Page changes separately..."
                Write-Host $filler -ForegroundColor Yellow
                Write-Log -Level Info -Message $filler
                Start-Sleep -Seconds 2															

                Try{
                    Apply-PnPProvisioningTemplate -path $Script:TemplatePath -Handlers SiteSecurity, Pages -Parameters @{"licenseListID" = $licenseListId; "site" = $SolutionsSiteUrl }												  
                }
                #If this is a GROUP#0 Site we can continue, just no Site Page unfortunately
                Catch [System.Management.Automation.RuntimeException] {
                    If((Get-PnPProperty -ClientObject (Get-PnPWeb) -Property WebTemplate) -eq 'GROUP'){
                        Write-Log -Level Warn -Message "GROUP#0 Site, non terminating error, continuing."
                    }
                    Else {
                        Throw $_.Exception.Message
                    }
                }
                Catch {
                    Throw $_.Exception.Message
                }
                    
                #Upload logo to Solutions Site
                Try {
                    $addLogo = Add-PnPfile -Path $PathImage -Folder "SiteAssets"
                }
                Catch {
                    Throw $_.Exception.Message
                }

                $filler = "Template Application complete!"
                Write-Host $filler -ForeGroundColor Green
                Write-Log -Level Info -Message $filler
                }
            Catch {
                Throw $_.Exception.Message
            }

            #Stage 3 Create the License Item and clean up
            Try {
                $stage = "Stage 3/3 - License Item creation"
                Write-Host "`n$stage`n" -ForegroundColor Yellow
                Write-Progress -Activity "Solutions Site Deployment" -CurrentOperation $stage -PercentComplete (100)

                $filler = "Creating License Item..."
                Write-Host $filler -ForegroundColor Yellow
                Write-Log -Level Info -Message $filler

                #Check if License Item exists
                $licenseItemCount = ((Get-PnPListItem -List "Licenses" -Query "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>License</Value></Eq></Where></Query></View>").Count)
                
                #Create License item if it does not exist
                If ($licenseItemCount -eq 0) {
                    Add-PnPListItem -List "Licenses" -Values @{"Title" = "License" } | Out-Null
                    $filler = "License Item created!"
                    Write-Host "`n$filler" -ForegroundColor Green
                    Write-Log -Level Info -Message $filler
                }
                Else {
                    $filler = "License Item not created or is duplicate!"
                    Write-Log -Level Warn -Message $filler
                }
            
                #This sets up a Custom Column Mapping list ready for use if required
                If($null -ne (Get-PnPList -Identity 'Custom Column Mapping')) {
                    Write-Log -Level Info -Message "Creating Custom Column Mapping list for later use if required."
                    Try {
                        New-PnPList -Title 'Custom Column Mapping' -Template GenericList | Out-Null

                        Add-PnPField -List 'Custom Column Mapping' -DisplayName 'From Column' -InternalName 'From Column' -Type Text -Required -AddToDefaultView  | Out-Null
                        Set-PnPField -List 'Custom Column Mapping' -Identity 'From Column' -Values @{Description = "This is the field (by internal name) you want to map from to an existing field" }

                        Add-PnPField -List 'Custom Column Mapping' -DisplayName 'To Column' -InternalName 'To Column' -Type Text -Required -AddToDefaultView  | Out-Null
                        Set-PnPField -List 'Custom Column Mapping' -Identity 'To Column' -Values @{Description = "This is the field (by internal name) you want to map to. This should already exist" }

                        Set-PnPField -List 'Custom Column Mapping' -Identity 'Title' -Values @{Title = "Scope"; DefaultValue = "Global" }
                    }
                    Catch {
                        Write-Log -Level Warn -Message "Issue creating Custom Column Mapping List. May already exist."
                    }
                }
                Else {
                    Write-Log -Level Info -Message "Custom Column Mapping list already exists by name, skipping creation."
                }

                Write-Log -Level Info -Message "Solutions Site URL = $SolutionsSiteUrl"
                Write-Log -Level Info -Message "License List URL = $LicenseListUrl"
                Write-Log -Level Info -Message "License List ID = $licenseListId"
                Write-Log -Level Info -Message "Uploading log file to $SolutionsSiteUrl/Shared%20Documents"

                #Upload log file to Solutions Site
                Try {
                    $logToSharePoint = Add-PnPfile -Path $script:LogPath -Folder "Shared Documents"
                }
                Catch {
                    Throw $_.Exception.Message
                }

                Write-Progress -Activity "Completed" -Completed

                Write-Host "`nPlease record the OnePlace Solutions Site URL and License Location / License List URL for usage in the OnePlaceMail Desktop and OnePlaceDocs clients, and the License List Id for the licensing process. " -ForegroundColor Yellow
                Write-Host "`nThese have also been written to a log file at '$script:logPath', and '$SolutionsSiteUrl/Shared%20Documents/$script:logFile'." -ForegroundColor Yellow
                Write-Host "`n-------------------`n" -ForegroundColor Red
    
                $importants = "Solutions Site URL = $SolutionsSiteUrl`nLicense List URL   = $LicenseListUrl`nLicense List ID    = $licenseListId"
                Write-Host $importants

                Write-Host "`n-------------------`n" -ForegroundColor Red
                
                #Is this the Administrator account?
                $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        
                If ($false -eq $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                    $input = Read-Host "Would you like to email this information and Log file to OnePlace Solutions now? (yes or no)"
                    $input = $input[0]
                    If ($input -eq 'y') {
                        $file = Get-ChildItem $script:logPath
                        Send-OutlookEmail -attachment $file.FullName -body $importants
                    }
                }
                Else {
                    Write-Host "Script is run as Administrator, cannot compose email details. Please email the above information and the log file generated to 'success@oneplacesolutions.com'." -ForegroundColor Yellow
                }
                Write-Host "Opening Solutions Site at $SolutionsSiteUrl..." -ForegroundColor Yellow

                Pause
                Start-Process $SolutionsSiteUrl | Out-Null
            }
            Catch {
                Throw $_.Exception.Message
            }
        }

        function showMenu { 
            Clear-Host 
            Write-Host "`n--------------------------------------------------------------------------------`n" -ForegroundColor Red
            Write-Host 'Welcome to the Solutions Site Deployment Script for OnePlace Solutions' -ForegroundColor Green
            Write-Host "`n--------------------------------------------------------------------------------`n" -ForegroundColor Red
            Write-Host 'Please make a selection:' -ForegroundColor Yellow
            Write-Host "1: Deploy a new Solutions Site" 
            Write-Host "2: Deploy the Solutions Site template to an existing Site Collection"
            Write-Host "Q: Press 'Q' to quit." 
            Write-Log -Level Info -Message "Displaying Menu"
        }

        Write-Log -Level Info -Message "Logging script actions to $script:logPath"
        
        do {
            showMenu
            $userInput = Read-Host "Please select an option" 
            Write-Log -Level Info -Message "User has entered option '$userInput'"
            switch ($userInput) { 
                '1' {
                    Deploy
                }
                '2' {
                    $script:doSiteCreation = $false
                    $script:onlyPnP = $true
                    Deploy
                }
                'q' {Exit}
            }
        }
        until($userInput -eq 'q') {}
    }
    Catch {
        $exType = $($_.Exception.GetType().FullName)
        $exMessage = $($_.Exception.Message)
        Write-Host "`nCaught an exception, further debugging information below:" -ForegroundColor Red
        Write-Log -Level Error -Message "Caught an exception. Exception Type: $exType. $exMessage"
        Write-Host $exMessage -ForegroundColor Red
        Write-Host "`nPlease send the log file at '$script:logPath' to 'support@oneplacesolutions.com' for assistance." -ForegroundColor Yellow
        Pause
    }
    #Clean up and disconnect any leftover PnPOnline or SPOService sessions
    Finally {
        Try {
            Disconnect-PnPOnline -ErrorAction SilentlyContinue
        }
        Catch {}
        Try {
            Disconnect-SPOService -ErrorAction SilentlyContinue
        }
        Catch {}
        Write-Log -Level Info -Message "End of script."
    }
}
Catch {
    $_
}