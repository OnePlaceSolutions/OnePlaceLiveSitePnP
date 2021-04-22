<#  
    .NOTES 
        Created by: Ashley Gregory
    .LINK (original)
        https://github.com/OnePlaceSolutions/OnePlaceLiveSitePnP
       
    This script optionally creates a new Site collection ('Team Site (Modern)' by default, 'Team Site (Classic)' by option), and applies the configuration changes / PnP template for the OnePlace Solutions site.
    All major actions are logged to 'OPSScriptLog.txt' in the user's or Administrators Documents folder, and it is uploaded to the Solutions Site at the end of provisioning.
#>
$ErrorActionPreference = 'Stop'
$script:logFile = "OPSScriptLog$(Get-Date -Format "MMddyyyy").txt"
$script:logPath = "$env:userprofile\Documents\$script:logFile"

#URL suffix of the Site Collection to create (if we create one)
$script:solutionsSite = 'oneplacesolutions'

#Set this to $false to create and/or provision to a classic site (STS#0) and template (v2 SPO) instead of a modern site (STS#3) and template (v3 SPO). v3 SPO is required for deployment to Group Sites (GROUP#0).
#Default: $true
$script:doModern = $true

#This handles whether SharePoint Online Management Shell authentication is being forced (Legacy PnP only)
#Default: $true
$script:forceSPOMS = $true

#This handles whether PnPManagementShell is being forced (PnP.PowerShell only)
#Default: $false
$script:forcePnPMS = $false

#Keep track of whether PnP.PowerShell is installed, otherwise we will default to Legacy PnP cmdlets
$script:PnPPowerShell = $null

#Keep track of whether Legacy PnP Cmdlets are installed.
$script:LegacyPnPPowerShell = $null

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

Write-Log -Level Info -Message "Start of script. Start of log."

Clear-Host 
Write-Host "`n--------------------------------------------------------------------------------`n" -ForegroundColor Red
Write-Host 'Welcome to the Solutions Site Deployment Script for OnePlace Solutions' -ForegroundColor Green
Write-Host "`n--------------------------------------------------------------------------------`n" -ForegroundColor Red

Start-Sleep -Seconds 2

Write-Host "Beginning script. Logging script actions to $script:logPath" -ForegroundColor Cyan

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
                Write-Log -Level Error -Message "Failed to open a new email in Outlook."
            }
        }
    
        function Invoke-Provision ([int]$count) {
            #Our first provisioning run can encounter a 403 if SharePoint has incorrectly told us the site is ready, this function will retry 
            Try {
                Write-Log -Message "Provisioning attempt $($count)"
                If($null -eq $script:PnPPowerShell){
                    Apply-PnPProvisioningTemplate -path $Script:TemplatePath -ExcludeHandlers Pages, SiteSecurity -ClearNavigation -WarningAction Ignore
                }
                Else {
                    Invoke-PnPSiteTemplate -path $Script:TemplatePath -ExcludeHandlers Pages, SiteSecurity -ClearNavigation -WarningAction Ignore
                }
            }
            Catch [System.Net.WebException] {
                If ($($_.Exception.Message) -match '(403)') {
                    #SPO returning a trigger happy ready response, sleep for a bit...
                    $filler = "SharePoint Online incorrectly indicated the site is ready to provision, pausing the script to wait for it to catch up. Retrying in 5 minutes. Retry $count/4"
                    Write-Host $filler -ForegroundColor Yellow
                    Write-Log -Level Info -Message $filler

                    If ($count -lt 4) {
                        Start-Sleep -Seconds 300
                        [int]$count += 1
                        Invoke-Provision -count $count
                    }
                    Else {
                        $filler = "SharePoint Online is taking an unusual amount of time to create the site. Please check your SharePoint Admin Site in Office 365, and when the site is created please continue the script. Do not press Enter until you have confirmed the site has been completely created."
                        Write-Host $filler -ForegroundColor Red
                        Write-Log -Level Info -Message $filler
                        Write-Host "`n"
                        Pause
                        If($null -eq $script:PnPPowerShell){
                            Apply-PnPProvisioningTemplate -path $Script:TemplatePath -ExcludeHandlers Pages, SiteSecurity -ClearNavigation -WarningAction Ignore
                        }
                        Else {
                            Invoke-PnPSiteTemplate -path $Script:TemplatePath -ExcludeHandlers Pages, SiteSecurity -ClearNavigation -WarningAction Ignore
                        }
                    }
                }
                Else {
                    Throw
                }
            }
            Catch [System.Management.Automation.RuntimeException] {
                If((Get-PnPProperty -ClientObject (Get-PnPWeb) -Property WebTemplate) -eq 'GROUP'){
                    Write-Log -Message "GROUP#0 Site, non terminating error, continuing."
                }
                Else {
                    Throw
                }
            }
            Catch {
                Throw
            }
        }

        function Deploy ($createSite) {
            Write-Log -Level Info -Message "Creating Site from scratch? $createSite"
            Write-Log -Level Info -Message "Are we using SPOMS? $($script:forceSPOMS)"
            Write-Log -Level Info -Message "Are we forcing PnP MS? $($script:forcePnPMS)"
            
            #Stage 1a Creating a Solutions Site from scratch
            If($createSite) {
                $stage = "Stage 1/3 - Team Site (Modern) creation"
                Write-Host "`n$stage`n" -ForegroundColor Yellow
                Write-Progress -Activity "Solutions Site Deployment" -CurrentOperation $stage -PercentComplete (33)
                
                $rootSharePoint = Read-Host "Please enter your SharePoint Online Root Site Collection URL, eg (without quotes) 'https://contoso.sharepoint.com'"
                Write-Log -Level Info -Message "Root SharePoint: $rootSharePoint"
                $rootSharePoint = $rootSharePoint.Trim("'")
                $rootSharePoint = $rootSharePoint.Trim("/")
                Write-Log -Level Info -Message "Sanitized: $rootSharePoint"
                
                $tenant = $rootSharepoint  -match 'https://(?<Tenant>.+)\.sharepoint.com'
                $tenant = $Matches.Tenant

                $adminSharePoint = "https://$tenant-admin.sharepoint.com"

                If (([string]::IsNullOrWhiteSpace($rootSharePoint)) -or ([string]::IsNullOrWhiteSpace($tenant))) {
                    Write-Host "Root SharePoint URL invalid. Exiting script."
                    Write-Log -Level Error -Message "No valid Root Site Collection URL entered. Exiting script."
                    Exit
                }

                Try {
                    If ($script:forceSPOMS) {
                        Connect-PnPOnline -Url $adminSharePoint -SPOManagementShell -WarningAction Ignore

                        Write-Host "Prompting for SharePoint Online Management Shell Authentication. Please do not continue until you are logged in. If no prompt appears you may already be authenticated to this Tenant."
                        Start-Sleep -Seconds 5
                        #Legacy PnP doesn't wait for SPO Management Shell to complete it's login, have to pause here
                        Pause
                        #See if we can get the current web, throw an exception otherwise so we don't continue without being connected
                        Get-PnPWeb | Out-Null
                    }
                    Else {
                        If ($script:forcePnPMS) {
                            Connect-PnPOnline -Url $adminSharePoint -Interactive
                        }
                        Else {
                            Connect-PnPOnline -Url $adminSharePoint -UseWebLogin -WarningAction Ignore
                        }
                    }
                }
                Catch {
                    $exMessage = $($_.Exception.Message)
                    If ($exMessage -match "*(403)*") {
                        Write-Log -Level Error -Message $exMessage
                        $filler = "Error connecting to '$adminSharePoint'. Please ensure you have sufficient rights to create Site Collections in your Microsoft 365 Tenant. `nThis usually requires Global Administrative rights, or alternatively ask your SharePoint Administrator to perform the Solutions Site Setup."
                        Write-Host $filler -ForegroundColor Yellow
                        Write-Host "Please contact OnePlace Solutions Support if you are still encountering difficulties."
                        Write-Log -Level Info -Message $filler
                    }
                    ElseIf ($exMessage -match "*Connect-PnPOnline*") {
                        Write-Log -Level Error -Message "Pre-requisite PnP Cmdlets likely not installed. Please review documentation and try again."
                        Pause
                    }
                    Throw
                }

                Write-Log -Level Info -Message "Tenant set to $tenant"
                Write-Log -Level Info -Message "Admin SharePoint set to $adminSharePoint"
                Write-Log -Level Info -Message "Root SharePoint set to $rootSharePoint"

                Write-Log -Level Info -Message "Solutions Site URL suffix set to $script:solutionsSite"

                $SolutionsSiteUrl = $rootSharePoint + '/sites/' + $script:solutionsSite
                $LicenseListUrl = $SolutionsSiteUrl + '/lists/Licenses'

                Try {
                    $ownerEmail = Read-Host "Please enter the email address of the owner-to-be for this site. This should be your current credentials."
                    $ownerEmail = $ownerEmail.Trim()
                    If ([string]::IsNullOrWhiteSpace($ownerEmail)) {
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
                        Throw
                    }
                    ElseIf ($exMessage -match '401') {
                        $filler = "Authentication issue. `nIf the newly created Site Collection is visible in your SharePoint Online admin center, re-run the script and select Option 1 to deploy to that site."
                        Write-Log -Level Error -Message $filler
                    }
                    Else {
                        Throw
                    }
                }
                Catch {
                    Write-Log -level Info -Message "Something went wrong during Site Creation. Details following"
                    Throw
                }
                
            }
            #Stage 1b Skipping Site Creation, identifying Solutions Site instead
            Else {
                $stage = "Stage 1/3 - Identify Solutions Site"
                Write-Host "`n$stage`n" -ForegroundColor Yellow
                Write-Progress -Activity "Solutions Site Deployment" -CurrentOperation $stage -PercentComplete (33)
                
                $tempinput = Read-Host "What is the URL of the existing Site Collection you have created? `nEg, 'https://contoso.sharepoint.com/sites/oneplacesolutions'. Do not include trailing view information such as '/AllItems.aspx'."
                $tempinput = $tempinput.Trim()
                Write-Log "User has entered $tempinput for Existing Site Collection URL"
                If($tempinput.Length -ne 0){
                    $solutionsSiteUrl = $tempinput.TrimEnd('/')
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
                If ($script:forceSPOMS) {
                    If($createSite) {
                        Write-Host "Attempting to use existing SPO Management Shell Authentication..."
                        Connect-PnPOnline -Url $SolutionsSiteUrl -SPOManagementShell -WarningAction Ignore
                        Start-Sleep -Seconds 5
                    }
                    Else {
                        Write-Host "Attempting to use new SPO Management Shell Authentication..."
                        Try {Disconnect-SPOService}
                        Catch {}
                        Try {Disconnect-PnPOnline}
                        Catch {}
                        Connect-PnPOnline -Url $SolutionsSiteUrl -SPOManagementShell -WarningAction Ignore
                        Start-Sleep -Seconds 5
                        Pause
                    }
                    #PnP doesn't wait for SPO Management Shell to complete it's login, have to pause here
                }
                Else {
                    Write-Host "Please authenticate against the Site Collection"
                    Start-Sleep -Seconds 2
                    If ($script:forcePnPMS) {
                        Connect-PnPOnline -Url $SolutionsSiteUrl -Interactive
                    }
                    Else {
                        Connect-PnPOnline -Url $SolutionsSiteUrl -UseWebLogin -WarningAction Ignore
                    }
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
                If(-not (Test-Path $Script:templatePath)) {
                    Write-Log -Level Info -Message 'Local resources not present.'
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
                    If($null -eq $script:PnPPowerShell){
                        Apply-PnPProvisioningTemplate -path $Script:TemplatePath -Handlers SiteSecurity, Pages -Parameters @{"licenseListID" = $licenseListId; "site" = $SolutionsSiteUrl }	-ClearNavigation -WarningAction Ignore											  
                    }
                    Else {
                        Invoke-PnPSiteTemplate -path $Script:TemplatePath -Handlers SiteSecurity, Pages -Parameters @{"licenseListID" = $licenseListId; "site" = $SolutionsSiteUrl }	-ClearNavigation -WarningAction Ignore											  
                    }
                    
                    #Upload logo to Solutions Site
                    Add-PnPfile -Path $PathImage -Folder "SiteAssets"
                }

                Catch {
                    #If this is a GROUP#0 Site we can continue, just need to adjust some things
                    If((Get-PnPProperty -ClientObject (Get-PnPWeb) -Property WebTemplate) -eq 'GROUP'){
                        Write-Log -Message "GROUP#0 Site detected, non terminating error, continuing."
                    }
                    Else {
                        Throw
                    }
                }

                $filler = "Template Application complete!"
                Write-Host $filler -ForeGroundColor Green
                Write-Log -Level Info -Message $filler
                }
            Catch {
                Throw
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
                    Add-PnPListItem -List "Licenses" -Values @{"Title" = "If you do not have a Production license, this list will appear blank for now. You can safely delete this message." } | Out-Null
                }
                Else {
                    $filler = "License Item not created or is duplicate!"
                    Write-Log -Level Warn -Message $filler
                }
            
                #This sets up a Custom Column Mapping list ready for use if required
                If($null -eq (Get-PnPList -Identity 'Custom Column Mapping')) {
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

                Add-PnPfile -Path $script:LogPath -Folder "Shared Documents"

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
                    $tempinput = Read-Host "Would you like to email this information and Log file to OnePlace Solutions now? (yes or no)"
                    $tempinput = $input[0]
                    If ($tempinput -eq 'y') {
                        $file = Get-ChildItem $script:logPath
                        Send-OutlookEmail -attachment $file.FullName -body $importants
                    }
                }
                Else {
                    Write-Host "Script is run as Administrator, cannot compose email details. Please email the above information and the log file generated to 'success@oneplacesolutions.com'." -ForegroundColor Yellow
                }

                Write-Host "Opening Solutions Site at $SolutionsSiteUrl..." -ForegroundColor Yellow
                Pause

                #cleaning up the Navigation nodes, doing this late in case there's an issue
                If((Get-PnPProperty -ClientObject (Get-PnPWeb) -Property WebTemplate) -eq 'GROUP'){
                    Write-Log -Message "GROUP#0 Site detected, attempting clean up of navigation nodes"
                    Try {
                        Get-PnPNavigationNode | ForEach-Object {
                            If(@(2002,2004,2005,1033).Contains($_.Id)){
                                $_ | Remove-PnPNavigationNode -Force -ErrorAction Continue
                                }
                            }
                    }
                    Catch {
                        #Couldn't remove the nodes, not an issue though.
                    }
                }

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
            Write-Host "Site Deployment:" -ForegroundColor Yellow
            Write-Host "1: Deploy the Solutions Site template to an existing Group or Modern Team Site Collection"
            Write-Host "2: Create a new Modern Team Site Collection automatically and deploy the Solutions Site template"
            Write-Host "`nPnP Pre-Requisite Installation (only one set of PnP Cmdlets required):" -ForegroundColor Yellow
            Write-Host "3: Install Legacy SharePoint PnP PowerShell Cmdlets for current user"
            Write-Host "4: Install Current PnP.PowerShell Cmdlets for current user"
            Write-Host "`nAdditional Configuration:" -ForegroundColor Yellow
            Write-Host "L: Change Log file path (currently: '$script:logPath')"
            Write-Host "S: Toggle Force SharePoint Online Management Shell Authentication for Legacy PnP (currently: $script:forceSPOMS)"
            Write-Host "P: Toggle Force 365 App / PnP Management Shell Authentication (currently: $script:forcePnPMS) (App permissions will be prompted for if required)"
            Write-Host "U: Uninstall all PnP Cmdlets (Legacy/Current) for current user"

            Write-Host "`nQ: Press 'Q' to quit." 
            Write-Log -Level Info -Message "Displaying Menu"
        }

        Write-Log -Level Info -Message "Logging script actions to $script:logPath"
        $script:PnPPowerShell = Get-Module PnP.PowerShell
        If($null -ne $script:PnPPowerShell) {
            $script:forceSPOMS = $false
        }
        Write-Log -Level Info -Message "PnP.PowerShell Version: $([string]$script:PnPPowerShell)"
        $script:LegacyPnPPowerShell = Get-Module "SharePointPnPPowerShellOnline"
        Write-Log -Level Info -Message "Legacy PnP PowerShell Version: $([string]$script:LegacyPnPPowerShell)"
        [string]$script:PSVersion = (Get-Host | Select-Object Version)
        Write-Log "PowerShell Version: $([string]$script:PSVersion)"
        If(($script:PSVersion -like "7.*") -or ((Get-Host | Select-Object Name) -match "Visual Studio Code Host")) {
            Write-Log -Level Warn "PowerShell version $($script:PSVersion) requires using Current PnP Cmdlets (PnP.PowerShell). Using this version with Legacy PnP will result in script failure."
            Pause
        }

        do {
            showMenu
            $userInput = Read-Host "Please select an option" 
            Write-Log -Message "User has entered option '$userInput'"
            switch ($userInput) { 
                #Apply site template 
                '1' {
                    Deploy -createSite $false
                }
                #Create site and deploy (may need to force SPOMS / PNPMS)
                '2' {
                    Deploy -createSite $true

                }
                '3' {
                    Clear-Host
                    If($null -eq (Get-Module "SharePointPnPPowerShellOnline")) {
                        Write-Host "Invoking installation of the SharePoint PnP PowerShell Module for SharePoint Online, please accept the prompts for installation."
                        Write-Host "If you do not use PowerShell modules often, you will likely see a message related to an 'Untrusted Repository', this is PowerShell Gallery where the PnP Modules are downloaded from. Please selection option 'Y' or 'A'.`n"
                        Invoke-Expression -Command "Install-Module SharePointPnPPowerShellOnline -Scope CurrentUser"
                    }
                    Else {
                        Write-Host "Existing SharePointPnPPowerShell detected, skipping installation."
                    }
                    Pause
                }
                '4' {
                    Clear-Host
                    If($null -eq $script:PnPPowerShell) {
                        Write-Host "Invoking installation of the PnP.PowerShell for SharePoint Online, please accept the prompts for installation."
                        Write-Host "If you do not use PowerShell modules often, you will likely see a message related to an 'Untrusted Repository', this is PowerShell Gallery where the PnP Modules are downloaded from. Please selection option 'Y' or 'A'.`n"
                        
                        Invoke-Expression -Command "Install-Module PnP.PowerShell -Scope CurrentUser"
                    }
                    Else {
                        Write-Host "Existing PnP.PowerShell detected, skipping installation."
                    }
                    $script:PnPPowerShell = Get-Module PnP.PowerShell
                    Pause
                }
                'l' {
                    $newLogPath = (Read-Host "Please enter a new path including 'OPSScriptLog.txt' and quotes for the new log file. Eg, 'C:\Users\John\Documents\OPSScriptLog.txt'.")
                    $newLogPath = $newLogPath.Replace('\\','\')
                    If ([string]::IsNullOrWhiteSpace($newLogPath)) {
                        Write-Host "No path entered, keeping default '$script:logPath'"
                    }
                    Else {
                        Move-Item -Path $script:logPath -Destination $newLogPath
                        $script:logPath = $newLogPath
                    }
                    Pause
                }
                's'{
                    If($null -eq $script:PnPPowerShell) {
                        $script:forceSPOMS = -not $script:forceSPOMS
                        If($script:forceSPOMS) {
                            $script:forcePnPMS = -not $script:forceSPOMS
                            Write-Log -Message "Toggling PnPMS to $($script:forcePnPMS)"
                        }
                        Write-Log -Message "Toggling SPOMS to $($script:forceSPOMS)"
                    }
                    Else {
                        Write-Host "PnP.PowerShell installed, can't force SharePoint Online Management Shell Authentication..."
                        Pause
                    }
                }
                'p'{
                    If($null -ne $script:PnPPowerShell) {
                        $script:forcePnPMS = -not $script:forcePnPMS
                        If($script:forcePnPMS) {
                            $script:forceSPOMS = -not $script:forcePnPMS
                            Write-Log -Message "Toggling SPOMS to $($script:forceSPOMS)"
                        }
                        Write-Log -Message "Toggling PnPMS to $($script:forcePnPMS)"
                    }
                    Else {
                        Write-Host "PnP.PowerShell not installed, can't force PnP Management Shell Authentication..."
                        Pause
                    }
                }
                'u' {
                    Write-Log "Uninstalling any PnP Cmdlets found"
                    Write-Host "Uninstalling Legacy PnP Cmdlets if found..."
                    Try {
                        Get-InstalledModule "SharePointPnPPowerShell*" | Uninstall-Module
                    }
                    Catch {
                        Write-Host "Error encountered, Legacy PnP (SharePointPnPPowerShellOnline) likely not installed."
                        $_
                    }
                    Write-Host "Uninstalling Current PnP Cmdlets if found..."
                    Try {
                        Get-InstalledModule "PnP.PowerShell" | Uninstall-Module
                    }
                    Catch {
                        Write-Host "Error encountered, Current PnP Cmdlets (PnP.PowerShell) likely not installed."
                        $_
                    }
                    Start-Sleep -Seconds 3
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
        Write-Host "`nActual Error encountered: $exMessage" -ForegroundColor Red
        Write-Host "`nPlease send the log file at '$script:logPath' to 'support@oneplacesolutions.com' for assistance." -ForegroundColor Yellow
        Pause
    }
    #Clean up and disconnect any leftover PnPOnline sessions
    Finally {
        Try {
            Disconnect-PnPOnline -ErrorAction SilentlyContinue
        }
        Catch {}
        Write-Log -Level Info -Message "End of script. End of log."
    }
}
Catch {
    $_
}
