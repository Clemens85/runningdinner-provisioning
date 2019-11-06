Configuration JAVA_DSC
{
    param (
    )
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'cChoco'
    Import-DscResource -ModuleName 'xNetworking'

    Node $AllNodes.NodeName {

		# Set Java to path
		Script SetJavaToPath
		{
			GetScript = {
				return @{ Result = $env:Path }
			}
			SetScript = {
				# Try to find Java bin path and force the result to string
				[string]$javaBinPath = gci "${Env:ProgramFiles}\Java" -r -filter java.exe | Select Directory | Select-Object -first 1 | % { $_.Directory.FullName }
				# Adds javaBinPath to path variable
				$newPathValue = $env:Path + ";"+$javaBinPath

				[Environment]::SetEnvironmentVariable("Path", $newPathValue, [EnvironmentVariableTarget]::Machine)
				# Add also path to current session
				$env:Path = $newPathValue
			}
			TestScript = {
				# Try to find Java bin path and force the result to string
				[string]$javaBinPath = gci "${Env:ProgramFiles}\Java" -r -filter java.exe | Select Directory | Select-Object -first 1 | % { $_.Directory.FullName }
				if(-not $env:Path.Contains($javaBinPath))
				{
					# Do update
					Return $False
				}
				# Don't update
				Return $True
			}
		}

    }
}

$ConfigData = @{
    AllNodes =
    @(
        @{
            NodeName = "LocalHost"
        }
    )
}

JAVA_DSC -ConfigurationData $ConfigData
Start-DscConfiguration -Path .\JAVA_DSC -Wait -Verbose -Force
