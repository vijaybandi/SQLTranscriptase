﻿<#
.SYNOPSIS
    Gets the SQL Agent Jobs
	
.DESCRIPTION
   Writes the SQL Agent Jobs out to the "04 - Agent Jobs" folder
   One file per job 
   
.EXAMPLE
    04_Agent_Jobs.ps1 localhost
	
.EXAMPLE
    04_Agent_Jobs.ps1 server01 sa password

.Inputs
    ServerName, [SQLUser], [SQLPassword]

.Outputs

	
.NOTES
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


[string]$BaseFolder = (Get-Item -Path ".\" -Verbose).FullName

# Script Name
Write-Host  -f Yellow -b Black "04 - Agent Jobs"

# assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Output "Assuming localhost"
	$Sqlinstance = 'localhost'
}


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./04_Agent_Jobs.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
    Set-Location $BaseFolder
    exit
}


# Working
Write-Output "Server $SQLInstance"

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


# SMO Connection
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo') | Out-Null 
$server = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $SQLInstance

# Using SQL Auth?
if ($mypass.Length -ge 1 -and $myuser.Length -ge 1)
{
	$server.ConnectionContext.LoginSecure = $false 
	$server.ConnectionContext.Login=$myuser
	$server.ConnectionContext.Password=$mypass
	Write-Output "Using SQL Auth"
}
else
{
	Write-Output "Using Windows Auth"
}

$jobs = $server.JobServer.Jobs 
 
$fullfolderPath = "$BaseFolder\$sqlinstance\04 - Agent Jobs"
if(!(test-path -path $fullfolderPath))
{
	mkdir $fullfolderPath | Out-Null
}
 
 # Export with filename fixups
if ($jobs -ne $null)
{
    Write-Output "Exporting Agent Jobs:"
    ForEach ( $job in $jobs )
    {
        $myjobname = $job.Name
        $myjobname = $myjobname.Replace('\', '-')
        $myjobname = $myjobname.Replace('/', '-')
        $myjobname = $myjobname.Replace('&', '-')
        $myjobname = $myjobname.Replace(':', '-')
        $myjobname = $myjobname.replace('[','(')
        $myjobname = $myjobname.replace(']',')')
        
        $FileName = "$fullfolderPath\$myjobname.sql"
        $job.Script() | Out-File -filepath $FileName
		$myjobname
    }

    Write-Output ("Exported: {0} Jobs" -f $jobs.count)
}
else
{
    Write-Output "No Agent Jobs Found on $SQLInstance"        
    echo null > "$BaseFolder\$SQLInstance\04 - No Agent Jobs Found.txt"
    Set-Location $BaseFolder
    exit
}

# Return To Base
Set-Location $BaseFolder
