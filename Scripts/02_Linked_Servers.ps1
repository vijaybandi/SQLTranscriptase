﻿<#
.SYNOPSIS
    Gets the Linked Servers on the target server
	
.DESCRIPTION
   Writes the Linked Servers out to the "02 - Linked Servers" folder
   One file for all servers 
   Once recreated, you will have to input the server credentials, as passwords are NOT scripted out
   
.EXAMPLE
    02_Linked_Servers.ps1 localhost
	
.EXAMPLE
    02_Linked_Servers.ps1 server01 sa password

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

Import-Module “sqlps” -DisableNameChecking -erroraction SilentlyContinue

#  Script Name
Write-Host  -f Yellow -b Black "02 - Linked Servers"

# assume localhost
if ($SQLInstance.length -eq 0)
{
	Write-Output "Assuming localhost"
	$Sqlinstance = 'localhost'
}


# Usage Check
if ($SQLInstance.Length -eq 0) 
{
    Write-host -f yellow "Usage: ./02_Linked_Servers.ps1 `"SQLServerName`" ([`"Username`"] [`"Password`"] if DMZ machine)"
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

function CopyObjectsToFiles($objects, $outDir) {
	
	if (-not (Test-Path $outDir)) {
		[System.IO.Directory]::CreateDirectory($outDir) | out-null
	}
	
	foreach ($o in $objects) { 
	
		if ($o -ne $null) {
			
			$schemaPrefix = ""
			
			if ($o.Schema -ne $null -and $o.Schema -ne "") {
				$schemaPrefix = $o.Schema + "."
			}
		
			$fixedOName = $o.name.replace('\','_')			
			$scripter.Options.FileName = $outDir + $schemaPrefix + $fixedOName + ".sql"			
			$scripter.EnumScript($o)
		}
	}
}


# Create Output Folder
$fullfolderPath = "$BaseFolder\$sqlinstance\02 - Linked Servers"
if(!(test-path -path $fullfolderPath))
{
    mkdir $fullfolderPath | Out-Null
}

# Delete pre-existing negative file
if(test-path -path "$BaseFolder\$SQLInstance\02 - No Linked Servers Found.txt")
{
    Remove-Item "$BaseFolder\$SQLInstance\02 - No Linked Servers Found.txt"
}

$server = $SQLInstance
$LinkedServers_path	= $fullfolderPath+"\Linked_Servers.sql"

# Test for Username/Password needed to connect - else assume WinAuth passthrough
if ($mypass.Length -ge 1 -and $myuser.Length -ge 1) 
{
	Write-Output "Using Sql Auth"

    $srv = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
    $srv.ConnectionContext.LoginSecure=$false
    $srv.ConnectionContext.set_Login($myuser)
    $srv.ConnectionContext.set_Password($mypass)
    $scripter = New-Object ("Microsoft.SqlServer.Management.SMO.Scripter") ($srv)

    # Script out
    $LinkedServers = $srv.LinkedServers 
    #CopyObjectsToFiles $LinkedServers $LinkedServers_path

}
else
{
	Write-host "Using Windows Auth"

    $srv        = New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
    $scripter 	= New-Object ("Microsoft.SqlServer.Management.SMO.Scripter") ($server)

    # Script Out
    $LinkedServers = $srv.LinkedServers 
    #CopyObjectsToFiles $LinkedServers $LinkedServers_path
    $srv.LinkedServers | foreach {$_.Script()+ "GO"} | Out-File  $LinkedServers_path


}

# Return to Base
set-location $BaseFolder


