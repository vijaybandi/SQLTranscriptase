﻿<#
.SYNOPSIS
    Gets the Audits and Audit Specifications on the target server
	
.DESCRIPTION
   Writes the SQL Server Credentials out to the "16 - Audits" folder
   Saves the Server-level audits and specs as "Servername_ServerAudit_Auditname.sql" and the "ServerName_ServerAuditSpec_SpecName.sql"
   Saves the Database-level Audits and Specs into their own folder   
   
.EXAMPLE
    16_Audits.ps1 localhost
	
.EXAMPLE
    16_Audits.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs

	
.NOTES
    MSDN References:
    https://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.audit.enumserverauditspecification.aspx
    https://msdn.microsoft.com/en-us/library/microsoft.sqlserver.management.smo.audit.enumdatabaseauditspecification.aspx

    George Walkey
    Richmond, VA USA
	
.LINK
    https://github.com/gwalkey
	
#>

Param(
  [string]$SQLInstance,
  [string]$myuser,
  [string]$mypass
)

#cls
[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

Write-Host  -f Yellow -b Black "16 - Audits"

# assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Output "Assuming localhost"
	$Sqlinstance = 'localhost'
}


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./16_Audits.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}


# Working
Write-Output "Server $SQLInstance"

import-module "sqlps" -DisableNameChecking -erroraction SilentlyContinue

# Server connection check
$serverauth = "win"
if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
{
	Write-Output "Testing SQL Auth"
	try
    {
        $results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -Username $myuser -Password $mypass -QueryTimeout 10 -erroraction SilentlyContinue
        if($results -ne $null)
        {
            $myver = $results.Column1
            Write-Output $myver
            $serverauth="sql"
        }	
	}
	catch
    {
		Write-Host -f red "$SQLInstance appears offline - Try Windows Auth?"
        Set-Location $BaseFolder
		exit
	}
}
else
{
	Write-Output "Testing Windows Auth"
 	Try
    {
        $results = Invoke-SqlCmd -ServerInstance $SQLInstance -Query "select serverproperty('productversion')" -QueryTimeout 10 -erroraction SilentlyContinue
        if($results -ne $null)
        {
            $myver = $results.Column1
            Write-Output $myver
        }
	}
	catch
    {
	    Write-Host -f red "$SQLInstance appears offline - Try SQL Auth?" 
        Set-Location $BaseFolder
	    exit
	}

}


# Load SQL SMO Assemblies
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMOExtended') | out-null

# Get Server Object
$server = $SQLInstance

if ($serverauth -eq "win")
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
}
else
{
    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
    $srv.ConnectionContext.LoginSecure=$false
    $srv.ConnectionContext.set_Login($myuser)
    $srv.ConnectionContext.set_Password($mypass)
}


# Create Output folder
$fullfolderPath = "$BaseFolder\$sqlinstance\16 - Audits"
if(!(test-path -path $fullfolderPath))
{
    mkdir $fullfolderPath | Out-Null
}


# -----------------
# 1) Server Audits
# -----------------
foreach($Audit in $srv.Audits)
{

    # Skip System Databases
    #if ($sqlDatabase.Name -in 'Master','Model','MSDB','TempDB') {continue} # you may want to script these...

    # Script out objects for each DB
    $strmyauditName = $SQLInstance+"_ServerAudit_"+$audit.name+".sql"
    $strmyaudit = $Audit.script()
    $output_path = "$BaseFolder\$SQLInstance\16 - Audits\$strmyAuditName"
    Write-Output ("Server Audit: {0}" -f $audit.Name)
    $strmyaudit | out-file $output_path -Force -encoding ascii
}



# -------------------------------
# 2) Server Audit Specifications
# -------------------------------
foreach($Audit in $srv.ServerAuditSpecifications)
{

    # Skip System Databases
    #if ($sqlDatabase.Name -in 'Master','Model','MSDB','TempDB') {continue}


    # Script out objects for each DB
    $strmyauditName = $SQLInstance+"_ServerAuditSpec_"+$audit.name+".sql"
    $strmyaudit = $Audit.script()
    $output_path = "$BaseFolder\$SQLInstance\16 - Audits\$strmyAuditName"
    Write-Output ("Server Audit Spec: {0}" -f $audit.Name)
    $strmyaudit | out-file $output_path -Force -encoding ascii

}



# -------------------
# 3) Database Audits
# -------------------
foreach($sqlDatabase in $srv.databases) 
{

    # Skip System Databases
    if ($sqlDatabase.Name -in 'Master','Model','MSDB','TempDB') {continue}

    # Script out Audits per DB
    $db = $sqlDatabase
    $fixedDBName = $db.name.replace('[','')
    $fixedDBName = $fixedDBName.replace(']','')
    $DB_Audit_output_path = "$BaseFolder\$SQLInstance\16 - Audits\$fixedDBName"    
            
    foreach($DBAudit in $db.DatabaseAuditSpecifications)
    {
        # Script out objects for each DB
        $strmyauditName = $fixedDBName+"_DBAuditSpec.sql"
        $strmyaudit = $DBAudit.script()
        $output_path = $DB_Audit_output_path+"\"+$strmyAuditName
        if(!(test-path -path $DB_Audit_output_path))
            {
                mkdir $DB_Audit_output_path | Out-Null
            }

        Write-Output ("Database Audits for: {0}" -f $fixedDBName)
        $strmyaudit | out-file $output_path -Force -encoding ascii
    }

}


# Return to Base
set-location $BaseFolder

