#!/usr/bin/env pwsh

# Copyright (c) 2021 vesoft inc. All rights reserved.
#
# This source code is licensed under Apache 2.0 License

$ErrorActionPreference = 'Stop'

# Usage: install.ps1

Function Print-Banner
{
    Write-Output  '+------------------------------------------------------------------------------------------+'
    Write-Output  '|   Nebula-Graph Playground is on the way...                                               |'
    Write-Output  '+------------------------------------------------------------------------------------------+'
    Write-Output  '|.__   __.  _______ .______    __    __   __          ___            __    __  .______     |'
    Write-Output  '||  \ |  | |   ____||   _  \  |  |  |  | |  |        /   \          |  |  |  | |   _  \    |'
    Write-Output  '||   \|  | |  |__   |  |_)  | |  |  |  | |  |       /  ^  \   ______|  |  |  | |  |_)  |   |'
    Write-Output  '||  . `  | |   __|  |   _  <  |  |  |  | |  |      /  /_\  \ |______|  |  |  | |   ___/    |'
    Write-Output  '||  |\   | |  |____ |  |_)  | |  `--   | |   ---- /  _____  \       |  `--   | |  |        |'
    Write-Output  '||__| \__| |_______||______/   \______/  |_______/__/     \__\       \______/  | _|        |'
    Write-Output  '+------------------------------------------------------------------------------------------+'
}

# Detect Network Env
Function Check-GoogleAccess
{
    Test-NetConnection -ComputerName "www.google.com" -CommonTCPPort HTTP -InformationLevel Quiet
}

# Install Dependencies(docker, Package Manager) with Network Env Awareness

Function Test-DockerExists
{
    try {
        $docker_version = docker version
        'True'
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        'False'
    }
}

Function Install-Choco
{
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

Function Test-DockerRunning
{
    try {
        $get_docker_proxy = Get-Process "com.docker.proxy" -ErrorAction Stop
        'True'
    }
    catch [System.Management.Automation.ActionPreferenceStopException] {
        'False'
    }

}

# https://gist.github.com/PrateekKumarSingh/65afe12a3fda5ef9ba42bf0673026728
Function Retry-Command
{
    [CmdletBinding()]
    param (
        [parameter(Mandatory, ValueFromPipeline)] 
        [ValidateNotNullOrEmpty()]
        [scriptblock] $ScriptBlock,
        [int] $RetryCount = 4,
        [int] $TimeoutInSecs = 15,
        [string] $SuccessMessage = "$ScriptBlock successfuly!",
        [string] $FailureMessage = "Failed to execute: $ScriptBlock"
        )
    process {
        $Attempt = 1
        $Flag = $true
        do {
            try {
                $PreviousPreference = $ErrorActionPreference
                $ErrorActionPreference = 'Stop'
                Invoke-Command -ScriptBlock $ScriptBlock -OutVariable Result
                $ErrorActionPreference = $PreviousPreference

                # flow control will execute the next line only if the command in the scriptblock executed without any errors
                # if an error is thrown, flow control will go to the 'catch' block
                Write-Verbose "$SuccessMessage `n"
                $Flag = $false
            }
            catch {
                if ($Attempt -gt $RetryCount) {
                    Write-Verbose "$FailureMessage! Total retry attempts: $RetryCount"
                    Write-Verbose "[Error Message] $($_.exception.message) `n"
                    $Flag = $false
                }
                else {
                    Write-Verbose "[$Attempt/$RetryCount] $FailureMessage. Retrying in $TimeoutInSecs seconds..."
                    Start-Sleep -Seconds $TimeoutInSecs
                    $Attempt = $Attempt + 1
                }
            }
        }
        While ($Flag)
    }
}

Function Ensure-Docker
{
    $docker_exists = Test-DockerExists

    Write-Output '[INFO] Checking Dependencies...'

    if ($docker_exists -eq 'True') {
        Write-Output '[INFO] Docker already exists.'
        Write-Output '[INFO] Trying to startup Docker Desktop'
        Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

    } else {
        # Install chco, docker, then start Docker Desktop
        Write-Output '[INFO] Docker not detected, installing now with Chocolatey'
        Install-Choco
        Write-Output '[INFO] Chocolatey installed, installing Docker Desktop now'
        C:\ProgramData\chocolatey\bin\choco.exe install docker-desktop --confirm
        Write-Output '[INFO] Docker Desktop installed, enabling Hyper-V service now'
        bcdedit /set hypervisorlaunchtype auto
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
        Write-Output '[INFO] Trying to startup Docker Desktop'
        Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    }

    # Retry for a while until docker is running
    Retry-Command -ScriptBlock {$_ = Get-Process "com.docker.proxy";$_  = & "C:\Program Files\Docker\Docker\resources\bin\docker.exe" ps} -Verbose `
        -RetryCount 6 -TimeoutInSecs 15 `
        -SuccessMessage "Docker Desktop Started." `
        -FailureMessage "Docker Desktop Start Failed."
}

# Check Ports States
# FIXME: To be added

# Deploy Nebula Graph

# Deploy Nebula Graph Studio

Function Main-Function
{
    Print-Banner

    $google_access = Check-GoogleAccess

    Ensure-Docker

}

Main-Function
# Deploy Nebula Console
