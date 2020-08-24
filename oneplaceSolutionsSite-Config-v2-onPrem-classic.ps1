﻿<#
    This script applies the configuration changes for the OnePlace Solutions site.
    All major actions are logged to 'OPSScriptLog.txt' in the user's or Administrators Documents folder, and it is uploaded to the Solutions Site at the end of provisioning.
#>
$ErrorActionPreference = 'Stop'
$script:logFile = "OPSScriptLog.txt"
$script:logPath = "$env:userprofile\Documents\$script:logFile"

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
 
        Begin {
            $VerbosePreference = 'SilentlyContinue' 
            $ErrorActionPreference = 'Continue'
        } 
        Process {
            # If the file already exists and NoClobber was specified, do not write to the log. 
            If ((Test-Path $Path) -AND $NoClobber){ 
                Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name." 
                Return 
            } 
 
            # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path. 
            ElseIf (!(Test-Path $Path)){ 
                Write-Verbose "Creating $Path." 
                $NewLogFile = New-Item $Path -Force -ItemType File 
            } 
 
            Else { 
                # Nothing to see here yet. 
            } 
 
            # Format Date for our Log File 
            $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss K" 
 
            # Write message to error, warning, or verbose pipeline and specify $LevelText 
            Switch($Level) { 
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

Write-Host "Beginning script. Logging script actions to $script:logPath" -ForegroundColor Cyan
Start-Sleep -Seconds 3

Try { 
    Set-ExecutionPolicy Bypass -Scope Process

    function Send-OutlookEmail ($attachment,$body) {
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

    Write-Host "`n--------------------------------------------------------------------------------`n" -ForegroundColor Red
    Write-Host 'Welcome to the Solutions Site deployment script for OnePlace Solutions.' -ForegroundColor Green
    Write-Host "`n--------------------------------------------------------------------------------`n" -ForegroundColor Red
    
    $stage = "Stage 1/3 - Connect to Site Collection"
    Write-Host "`n$stage`n" -ForegroundColor Yellow
    Write-Progress -Activity "Solutions Site Deployment" -CurrentOperation $stage -PercentComplete (33)
    Write-Host "Please ensure you have created a new Site Collection with the template 'Team Site' (classic if the option is given) and the URL '/oneplacesolutions'"
    $SolutionsSiteUrl = Read-Host -Prompt "Enter your new Site Collection URL here, eg http://contoso.com/sites/oneplacesolutions"
    $licenseListUrl = $SolutionsSiteUrl + "/Lists/Licenses"
    
    Try {

        $stage = "Stage 2/3 - Apply Solutions Site template"
        Write-Host "`n$stage`n" -ForegroundColor Yellow
        Write-Progress -Activity "Solutions Site Deployment" -CurrentOperation $stage -PercentComplete (66)

        #Connecting to the site collection to apply the template
        Connect-pnpOnline -url $SolutionsSiteUrl

        #Download OnePlace Solutions Site provisioning template
        $WebClient = New-Object System.Net.WebClient
        $Url = "https://raw.githubusercontent.com/OnePlaceSolutions/OnePlaceLiveSitePnP/master/oneplaceSolutionsSite-template-v2.xml"    
        $Path = "$env:temp\oneplaceSolutionsSite-template-v2.xml" 
        If(-not (Test-Path $Path)) {
            $filler = "Downloading provisioning xml template to: $Path"
            Write-Host $filler -ForegroundColor Yellow  
            Write-Log -Level Info -Message $filler
            $WebClient.DownloadFile( $Url, $Path )
        }
        #Download OnePlace Solutions Company logo to be used as Site logo    
        $UrlSiteImage = "https://raw.githubusercontent.com/OnePlaceSolutions/OnePlaceLiveSitePnP/master/oneplacesolutions-logo.png"
        $PathImage = "$env:temp\oneplacesolutions-logo.png" 
        If(-not (Test-Path $PathImage )) {
            $filler = "Downloading OPS logo for Solutions Site"
            Write-Host $filler -ForegroundColor Yellow 
            Write-Log -Level Info -Message $filler
            $WebClient.DownloadFile( $UrlSiteImage, $PathImage )
        }
        #Apply provisioning xml to new site collection
        $filler = "Applying configuration changes..."
        Write-Host $filler -ForegroundColor Yellow
        Write-Log -Level Info -Message $filler

        Apply-PnPProvisioningTemplate -path $Path -ExcludeHandlers SiteSecurity, Pages
		
		$licenseList = Get-PnPList -Identity "Licenses"
        $licenseListId = $licenseList.ID
        $licenseListId = $licenseListId.ToString()
    
        $filler = "Applying Site Security and Page changes separately..."
        Write-Host $filler -ForegroundColor Yellow
        Write-Log -Level Info -Message $filler
        Start-Sleep -Seconds 2
        Try {
            Apply-PnPProvisioningTemplate -path $Path -Handlers SiteSecurity, Pages -Parameters @{"licenseListID"=$licenseListId;"site"=$SolutionsSiteUrl;"version"="16.0.0.0"}
        }
        Catch {
            $filler = "Issue deploying SiteSecurity and Pages, likely running SharePoint 2013, retrying template deployment with fix..."
            Write-Log -Level Warn -Message $filler
            Apply-PnPProvisioningTemplate -path $Path -Handlers SiteSecurity, Pages -Parameters @{"licenseListID"=$licenseListId;"site"=$SolutionsSiteUrl;"version"="15.0.0.0"}
        }

        $filler = "Provisioning complete!"
        Write-Host $filler -ForeGroundColor Green
        Write-Log -Level Info -Message $filler

        $stage = "Stage 3/3 - License Item creation"
        Write-Host "`n$stage`n" -ForegroundColor Yellow
        Write-Progress -Activity "Solutions Site Deployment" -CurrentOperation $stage -PercentComplete (100)

        $filler = "Creating License Item..."
        Write-Host $filler -ForegroundColor Yellow
        Write-Log -Level Info -Message $filler

        $licenseItemCount = ((Get-PnPListItem -List "Licenses" -Query "<View><Query><Where><Eq><FieldRef Name='Title'/><Value Type='Text'>License</Value></Eq></Where></Query></View>").Count)
        If ($licenseItemCount -eq 0) {
            Add-PnPListItem -List "Licenses" -Values @{"Title" = "License"} | Out-Null
            $filler = "License Item created!"
            Write-Host "`n$filler" -ForegroundColor Green
            Write-Log -Level Info -Message $filler
        }
        Else {
            $filler = "License Item not created or is duplicate!"
            Write-Host "`n$filler" -ForegroundColor Red
            Write-Log -Level Warn -Message $filler
        }

        Write-Log -Level Info -Message "Solutions Site URL = $SolutionsSiteUrl"
        Write-Log -Level Info -Message "License List URL = $LicenseListUrl"
        Write-Log -Level Info -Message "License List ID = $licenseListId"
        Write-Log -Level Info -Message "Uploading log file to $SolutionsSiteUrl/Shared%20Documents"

        #This sets up a Custom Column Mapping list ready for use if required
        Write-Log -Level Info -Message "Creating Custom Column Mapping list for later use if required."
        New-PnPList -Title 'Custom Column Mapping' -Template GenericList | Out-Null

        Add-PnPField -List 'Custom Column Mapping' -DisplayName 'From Column' -InternalName 'From Column' -Type Text -Required -AddToDefaultView  | Out-Null
        Set-PnPField -List 'Custom Column Mapping' -Identity 'From Column' -Values @{Description = "This is the field (by internal name) you want to map from to an existing field"}

        Add-PnPField -List 'Custom Column Mapping' -DisplayName 'To Column' -InternalName 'To Column' -Type Text -Required -AddToDefaultView  | Out-Null
        Set-PnPField -List 'Custom Column Mapping' -Identity 'To Column' -Values @{Description = "This is the field (by internal name) you want to map to. This should already exist"}

        Set-PnPField -List 'Custom Column Mapping' -Identity 'Title' -Values @{Title = "Scope"; DefaultValue = "Global"}

        Try {
            #workaround for a PnP bug
            $logToSharePoint = Add-PnPfile -Path $script:LogPath -Folder "Shared Documents"
        }
        Catch {
            $exType = $($_.Exception.GetType().FullName)
            $exMessage = $($_.Exception.Message)
            Write-Host "Caught an exception:" -ForegroundColor Red
            Write-Host "Exception Type: $exType" -ForegroundColor Red
            Write-Host "Exception Message: $exMessage" -ForegroundColor Red
            Write-Log -Level Error -Message "Caught an exception. Exception Type: $exType"
            Write-Log -Level Error -Message $exMessage
        }

        Write-Progress -Activity "Completed" -Completed

        Write-Host "`nPlease record the OnePlace Solutions Site URL and License Location / License List URL for usage in the OnePlaceMail Desktop and OnePlaceDocs clients, and the License List Id for the licensing process. " -ForegroundColor Yellow
        Write-Host "`nThese have also been written to a log file at '$script:logPath', and '$SolutionsSiteUrl/Shared%20Documents/$script:logFile'." -ForegroundColor Yellow
        Write-Host "`n-------------------`n" -ForegroundColor Red
    
        $importants = "Solutions Site URL = $SolutionsSiteUrl`nLicense List URL   = $LicenseListUrl`nLicense List ID    = $licenseListId"
        Write-Host $importants

        Write-Host "`n-------------------`n" -ForegroundColor Red
        
        
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        
        If($false -eq $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            $input = Read-Host "Would you like to email this information and Log file to OnePlace Solutions now? (yes or no)"
            $input = $input[0]
            If($input -eq 'y') {
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
    Catch [Microsoft.SharePoint.Client.ServerException] {
        $exMessage = $($_.Exception.Message)
        If($exMessage -match 'A site already exists at url') {
            Write-Host $exMessage -ForegroundColor Red
            Write-Log -Level Error -Message $exMessage
            If($solutionsSite -ne 'oneplacesolutions'){
                Write-Host "Please run the script again and choose a different Solutions Site suffix." -ForegroundColor Red
            }
        }
        Else {
            Throw $_
        }
    }
    Catch {
        Throw $_
    }
}

Catch {
    $exType = $($_.Exception.GetType().FullName)
    $exMessage = $($_.Exception.Message)
    write-host "Caught an exception:" -ForegroundColor Red
    write-host "Exception Type: $exType" -ForegroundColor Red
    write-host "Exception Message: $exMessage" -ForegroundColor Red
    Write-Log -Level Error -Message "Caught an exception. Exception Type: $exType"
    Write-Log -Level Error -Message $exMessage
    Pause
}

Finally {
    Try {
        Disconnect-PnPOnline
    }
    Catch {}
    Write-Log -Level Info -Message "End of script."
}
