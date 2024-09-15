<#
    .SYNOPSIS
    Start Pode server

    .DESCRIPTION
    Test if it's running on Windows, then test if it's running with elevated Privileges, and start a new session if not.

    .EXAMPLE
    pwsh .\PodePSHTML\PodeServer.ps1
#>
[CmdletBinding()]
param ()

#region functions
function Initialize-FileWatcher {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$Watch
    )

    begin{
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose $('[', (Get-Date -f 'yyyy-MM-dd HH:mm:ss.fff'), ']', '[ Begin   ]', "$($function)", $Watch -Join ' ')
    }

    process{

        Add-PodeFileWatcher -Name PodePSHTML -Path $Watch -ScriptBlock {

            Write-Verbose "$($FileEvent.Name) -> $($FileEvent.Type) -> $($FileEvent.FullPath)"

            $BinPath  = Join-Path -Path $($PSScriptRoot) -ChildPath 'bin'

            try{
                "        - Received: $($FileEvent.Name) at $($FileEvent.Timestamp)" | Out-Default
                switch -Regex ($FileEvent.Type){
                    'Created|Changed' {
                        # Move-Item, New-Item
                        switch -Regex ($FileEvent.Name){
                            'index.txt' {
                                Start-Sleep -Seconds 3
                                Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
                                . $(Join-Path $BinPath -ChildPath 'New-PshtmlIndexPage.ps1') -Title 'Index' -Request 'FileWatcher'
                            }
                        }

                        $index   = Join-Path -Path $($PSScriptRoot) -ChildPath 'views/index.pode'
                        $content = Get-Content $index
                        $content -replace 'Created at\s\d{4}\-\d{2}\-\d{2}\s\d{2}\:\d{2}\:\d{2}', "Created at $(Get-Date -f 'yyyy-MM-dd HH:mm:ss')" | Set-Content -Path $index -Force -Confirm:$false

                    }
                    'Deleted' {
                        # Move-Item, Remove-Item
                    }
                    'Renamed' {
                        # Rename-Item
                    }
                    default {
                        "        - $($FileEvent.Type): is not supported" | Out-Default
                    }

                }
            }catch{
                Write-Warning "$($function): An error occured on line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
                $Error.Clear()
            }

        } -Verbose

    }

    end{
        Write-Verbose $('[', (Get-Date -f 'yyyy-MM-dd HH:mm:ss.fff'), ']', '[ End     ]', "$($MyInvocation.MyCommand.Name)" -Join ' ')
    }
}

function Initialize-WebEndpoints {
    [CmdletBinding()]
    param()

    begin{
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose $('[', (Get-Date -f 'yyyy-MM-dd HH:mm:ss.fff'), ']', '[ Begin   ]', "$($function)", $Watch -Join ' ')
    }

    process{
        # Index
        Add-PodeRoute -Method Get -Path '/' -ScriptBlock {
            Write-PodeViewResponse -Path 'Index.pode'
        }
        # Full Calendar
        Add-PodeRoute -Method Get -Path '/full-calendar' -ScriptBlock {
            Write-PodeViewResponse -Path 'full-calendar.pode'
        }
        # Year Calendar
        Add-PodeRoute -Method Get -Path '/year-calendar' -ScriptBlock {
            Write-PodeViewResponse -Path 'year-calendar.pode'
        }
    }

    end{
        Write-Verbose $('[', (Get-Date -f 'yyyy-MM-dd HH:mm:ss.fff'), ']', '[ End     ]', "$($MyInvocation.MyCommand.Name)" -Join ' ')
    }

}

function Initialize-ApiEndpoints {
    [CmdletBinding()]
    param()

    begin{
        $function = $($MyInvocation.MyCommand.Name)
        Write-Verbose $('[', (Get-Date -f 'yyyy-MM-dd HH:mm:ss.fff'), ']', '[ Begin   ]', "$($function)", $Watch -Join ' ')
    }

    process{
        $BinPath    = Join-Path -Path $($PSScriptRoot) -ChildPath 'bin'
        $UploadPath = $($BinPath).Replace('bin','upload')
    
        Add-PodeRoute -Method Post -Path '/api/submit' -ContentType 'application/json' -ArgumentList @($UploadPath) -ScriptBlock {
            param($UploadPath)
            
            # Lese die Formulardaten
            $name  = $WebEvent.Data['name']
            $type  = $WebEvent.Data['type']
            $start = $WebEvent.Data['start']
            $end   = $WebEvent.Data['end']
            
            # Daten verarbeiten (z.B. in eine Datenbank oder eine Datei schreiben)
            # Hier speicherst du die Daten in eine einfache CSV-Datei
            $data = @{
                Name  = $name
                Type  = $type
                Start = $start
                End   = $end
            }
            $data | Export-Csv -Path (Join-Path -Path $UploadPath -ChildPath "calendar.csv") -Append -NoTypeInformation
    
            # Gib eine Bestätigung an den Benutzer zurück
            Write-PodeJsonResponse -Value @{ message = "Abwesenheit eingetragen!" }
        }

        # Route zum Abrufen der Events als JSON
        Add-PodeRoute -Method Get -Path '/api/events' -ScriptBlock {
            # Beispieldaten (in einem realen Szenario könntest du diese aus einer Datenbank laden)
            $events = @(
                @{
                    title = 'Ferien - Max Mustermann'
                    start = '2024-09-20'
                    end = '2024-09-25'
                },
                @{
                    title = 'Militärdienst - John Doe'
                    start = '2024-10-01'
                    end = '2024-10-10'
                }
            )

            # Gebe die Events als JSON aus
            Write-PodeJsonResponse -Value $events
        }
    
        # Add-PodeRoute -Method Post -Path '/api/index' -ArgumentList @($BinPath) -ScriptBlock {
        #     param($BinPath)
        #     if($CurrentOS -eq [OSType]::Windows){Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force}
        #     $Response = . $(Join-Path $BinPath -ChildPath 'New-PshtmlIndexPage.ps1') -Title 'Index' -Request 'API'
        #     Write-PodeJsonResponse -Value $Response
        # }
    
        # Add-PodeRoute -Method Post -Path '/api/pode' -ArgumentList @($BinPath) -ScriptBlock {
        #     param($BinPath)
        #     if($CurrentOS -eq [OSType]::Windows){Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force}
        #     $Response = . $(Join-Path $BinPath -ChildPath 'New-PshtmlPodeServerPage.ps1') -Title 'Pode Server' -Request 'API'
        #     Write-PodeJsonResponse -Value $Response
        # }
    
        # Add-PodeRoute -Method Post -Path '/api/asset' -ArgumentList @($BinPath) -ScriptBlock {
        #     param($BinPath)
        #     if($CurrentOS -eq [OSType]::Windows){Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force}
        #     $Response = . $(Join-Path $BinPath -ChildPath 'New-PshtmlUpdateAssetPage.ps1') -Title 'Update Assets' -Request 'API'
        #     Write-PodeJsonResponse -Value $Response
        # }
    
        # Add-PodeRoute -Method Post -Path '/api/sqlite' -ContentType 'application/text' -ArgumentList @($BinPath) -ScriptBlock {
        #     param($BinPath)
        #     if($CurrentOS -eq [OSType]::Windows){Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force}
        #     $Response = . $(Join-Path $BinPath -ChildPath 'New-PshtmlSQLitePage.ps1') -Title 'SQLite Data' -Request 'API' -TsqlQuery $WebEvent.Data
        #     Write-PodeJsonResponse -Value $Response
        # }
    
        # Add-PodeRoute -Method Post -Path '/api/pester' -ContentType 'application/json' -ArgumentList @($BinPath) -ScriptBlock {
        #     param($BinPath)
        #     if($CurrentOS -eq [OSType]::Windows){Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force}
        #     Import-Module Pester
        #     if($WebEvent.Data -is [system.array]){
        #         $data = $WebEvent.Data
        #     }else{
        #         $data = @('example.ch')
        #     }
        #     # In a container it's possible to pass variables
        #     $ContainerSplat = @{
        #         Path   = $(Join-Path $BinPath -ChildPath 'Invoke-PesterResult.Tests.ps1')
        #         Data   = @{ Destination = $data}
        #     }
        #     $container  = New-PesterContainer @ContainerSplat
        #     # Exclude Tests with the Tag NotRun
        #     $PesterData = Invoke-Pester -Container $container -PassThru -Output None -ExcludeTagFilter NotRun
        #     $Response = . $(Join-Path $BinPath -ChildPath 'New-PshtmlPesterPage.ps1') -Title 'Pester Result' -Request 'API' -PesterData $PesterData
        #     if([String]::IsNullOrEmpty($Response)){
        #         Write-PodeJsonResponse -Value 'Could not read pester results' -StatusCode 400
        #     }else{
        #         Write-PodeJsonResponse -Value $Response
        #     }
        # }
    
        # Add-PodeRoute -Method Post -Path '/api/mermaid' -ContentType 'application/text' -ArgumentList @($BinPath) -ScriptBlock {
        #     param($BinPath)
        #     if($CurrentOS -eq [OSType]::Windows){Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force}
        #     $Response = . $(Join-Path $BinPath -ChildPath 'New-PshtmlMermaidPage.ps1') -Title 'Mermaid Diagram' -Request 'API' -TsqlQuery $WebEvent.Data
        #     Write-PodeJsonResponse -Value $Response
        # }
    
        # Add-PodeRoute -Method Post -Path '/api/help' -ArgumentList @($BinPath) -ScriptBlock {
        #     param($BinPath)
        #     if($CurrentOS -eq [OSType]::Windows){Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force}
        #     $Response = . $(Join-Path $BinPath -ChildPath 'New-PshtmlHelpPage.ps1') -Title 'Help' -Request 'API'
        #     Write-PodeJsonResponse -Value $Response
        # }
    }

    end{
        Write-Verbose $('[', (Get-Date -f 'yyyy-MM-dd HH:mm:ss.fff'), ']', '[ End     ]', "$($MyInvocation.MyCommand.Name)" -Join ' ')
    }

}
#endregion

#region Main
enum OSType {
    Linux
    Mac
    Windows
}

if($PSVersionTable.PSVersion.Major -lt 6){
    $CurrentOS = [OSType]::Windows
}else{
    if($IsMacOS)  {$CurrentOS = [OSType]::Mac}
    if($IsLinux)  {$CurrentOS = [OSType]::Linux}
    if($IsWindows){$CurrentOS = [OSType]::Windows}
}
#endregion

#region Pode server
if($CurrentOS -eq [OSType]::Windows){
    $Address = 'localhost'
}else{
    $Address = '*'
}
$Port = 8080
$Protocol = 'http'

# We'll use 2 threads to handle API requests
Start-PodeServer -Browse -Threads 2 {
    Write-Host "Press Ctrl. + C to terminate the Pode server" -ForegroundColor Yellow

    if($CurrentOS -eq [OSType]::Mac){
        Write-Host "Re-builds of pages not supportet on $($CurrentOS), because mySQLite support only Windows and Linux" -ForegroundColor Red
    }

    # Enables Error Logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # Add listener to Port 8080 for Protocol http
    Add-PodeEndpoint -Address $Address -Port $Port -Protocol $Protocol

    # Set the engine to use and render .pode files
    Set-PodeViewEngine -Type Pode

    # Add File Watcher
    # $WatcherPath = Join-Path -Path $($PSScriptRoot) -ChildPath 'upload'
    # Initialize-FileWatcher -Watch $WatcherPath
    
    # Set Pode endpoints for the web pages
    Initialize-WebEndpoints

    # Set Pode endpoints for the api
    Initialize-ApiEndpoints

} -Verbose 

#endregion