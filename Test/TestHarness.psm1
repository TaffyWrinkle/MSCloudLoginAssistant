function Invoke-TestHarness
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.String]
        $TestResultsFile,

        [Parameter()]
        [System.String]
        $DscTestsPath,

        [Parameter()]
        [Switch]
        $IgnoreCodeCoverage
    )


    Write-Verbose -Message 'Starting all MSCloudLoginAssistant tests'

    $repoDir = Join-Path -Path $PSScriptRoot -ChildPath '..\' -Resolve

    $testCoverageFiles = @()
    if ($IgnoreCodeCoverage.IsPresent -eq $false)
    {
        Get-ChildItem -Path "$repoDir\modules\MSCloudLoginAssistant\*.psm1" -Recurse | ForEach-Object {
            $testCoverageFiles += $_.FullName
        }
    }

    $testResultSettings = @{ }
    if ([String]::IsNullOrEmpty($TestResultsFile) -eq $false)
    {
        $testResultSettings.Add('OutputFormat', 'NUnitXml' )
        $testResultSettings.Add('OutputFile', $TestResultsFile)
    }
    Import-Module -Name "$repoDir\modules\MSCloudLoginAssistant\MSCloudLoginAssistant.psd1"
    $testsToRun = @()

    # Run Unit Tests
    $versionsPath = Join-Path -Path $repoDir -ChildPath "\Test\Unit\Stubs\"
    $versionsToTest = (Get-ChildItem -Path $versionsPath).Name
    # Import the first stub found so that there is a base module loaded before the tests start
    $firstStub = Join-Path -Path $repoDir `
        -ChildPath "\Test\Unit\Stubs\MSCloudLoginAssistant.psm1"
    Import-Module $firstStub -WarningAction SilentlyContinue

    $versionsToTest | ForEach-Object -Process {
        $stubPath = Join-Path -Path $repoDir `
            -ChildPath "\Test\Unit\Stubs\MSCloudLoginAssistant.psm1"
        $testsToRun += @(@{
                'Path'       = (Join-Path -Path $repoDir -ChildPath "\Test\Unit")
                'Parameters' = @{
                    'CmdletModule' = $stubPath
                }
            })
    }

    # DSC Common Tests
    if ($PSBoundParameters.ContainsKey('DscTestsPath') -eq $true)
    {
        $getChildItemParameters = @{
            Path    = $DscTestsPath
            Recurse = $true
            Filter  = '*.Tests.ps1'
        }

        # Get all tests '*.Tests.ps1'.
        $commonTestFiles = Get-ChildItem @getChildItemParameters

        # Remove DscResource.Tests unit tests.
        $commonTestFiles = $commonTestFiles | Where-Object -FilterScript {
            $_.FullName -notmatch 'DSCResource.Tests\\Tests'
        }

        $testsToRun += @( $commonTestFiles.FullName )
    }

    if ($IgnoreCodeCoverage.IsPresent -eq $false)
    {
        $testResultSettings.Add('CodeCoverage', $testCoverageFiles)
    }

    $results = Invoke-Pester -Script $testsToRun -PassThru @testResultSettings

    return $results
}