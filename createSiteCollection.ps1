 <#
        This script prompt creates a new site collection in your Office 365 tenant
        The user is prompted for the SharePoint Site Collection url, Site Owner and TimeZone of the newly created
        Site Collection and the template used is the team site  
#>

try {    
    Set-ExecutionPolicy Bypass -Scope Process

    #Prompt for SharePoint Url     
    $SharePointUrl = Read-Host -Prompt 'Enter the url of your new OnePlaceLive Site Collection'

    #Prompt for SharePoint Site Owner (email address)    
    $SiteOwner = Read-Host -Prompt 'Enter the site owner of your new OnePlaceLive Site Collection'

    #Prompt for timezone of newly created site collection (enter id number)
    Get-PnPTimeZoneId | Out-Host
    $TZone = Read-Host -Prompt 'Choose timezone id based on values above'

    #Create site collection based on team site template
    New-PnPTenantSite -Owner $SiteOwner -Title 'OnePlace Solutions Live Site' -Url $SharePointUrl -Template 'STS#0' -TimeZone $TZone  
    
}
catch {
    Write-Host $error[0].Message
}
