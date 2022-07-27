$folderPath = Read-Host -Prompt "Please enter folder path"

while (-not(Test-Path -Path $folderPath)) {
    Write-Host "`nPath does not exist`n"
    $folderPath = Read-Host -Prompt "Please enter folder path"
}

$folder = $folderPath.Split("\")[-1]

$name = $folderPath.Substring(8, $folderPath.length - 8)

$name = $name.Split("\") -join ""

$baselineName = ".\"+ $name + "base.txt"

Write-Host "`nWhat would you like to do?`n"
Write-Host "    A) Collect new Baseline?`n"
Write-Host "    B) Begin monitoring files with saved Baseline?`n"
$response = Read-Host -Prompt "Please enter 'A' or 'B'`n"

if (-not($response -eq "A".ToUpper() -or $response -eq "B".ToUpper())) {
    [bool] $loop = 1
    while ($loop) {
        Write-Host "`nIncorrect Input `nPlease enter 'A' or 'B'"
        Write-Host "What would you like to do?`n"
        Write-Host "    A) Collect new Baseline?`n"
        Write-Host "    B) Begin monitoring files with saved Baseline?`n"
        $response = Read-Host -Prompt "Please enter 'A' or 'B'`n"

        if ($response -eq "A".ToUpper() -or $response -eq "B".ToUpper()) {
            $loop = 0
        }
    }
}

Function Calculate-File-Hash($filepath) {
    $filehash = Get-FileHash -Path $filepath -Algorithm SHA512
    return $filehash
}

Function Erase-Baseline-If-Already-Exists() {
    $baselineExists = Test-Path -Path $baselineName #.\baseline.txt

    if ($baselineExists) {
        Remove-Item -Path $baselineName #.\baseline.txt
    }
}

Function Create-Baseline() {
    $files = Get-ChildItem -Path $folderPath

    foreach ($f in $files) {
        $hash = Calculate-File-Hash $f.FullName
        "$($hash.Path)|$($hash.Hash)" | Out-File -FilePath $baselineName -Append
    }
}

Function Make-Baseline-Dictionary() {
    $Dictionary = @{}

    $filePathsAndHashes = Get-Content -Path $baselineName #.\baseline.txt
    
    foreach ($f in $filePathsAndHashes) {
         $Dictionary.add($f.Split("|")[0],$f.Split("|")[1])
    }

    return $Dictionary
}

Function Authorise-Or-View-Change($path) {
    Write-Host "What would you like to do?`n"
    Write-Host "    T) Authorise change`n"
    Write-Host "    V) View change`n"
    $decision = Read-Host -Prompt "Please enter 'T' or 'V'`n"

    [bool] $monitor = 0

    if (-not($decision -eq "T".ToUpper() -or $decision -eq "V".ToUpper())) {
        [bool] $loop = 1
        while ($loop) {
            Write-Host "`nIncorrect Input `nPlease enter 'T' or 'V'"
            Write-Host "What would you like to do?`n"
            Write-Host "    T) Authorise change`n"
            Write-Host "    V) View change`n"
            $decision = Read-Host -Prompt "Please enter 'T' or 'V'`n"

            if ($decision -eq "T".ToUpper() -or $decision -eq "V".ToUpper()) {
                $loop = 0
            }
        }
    }

    if ($decision -eq "T".ToUpper()) {
        return 1
    }
    elseif ($decision -eq "V".ToUpper()) {
        Invoke-Item $path
        return 0
    }

}

if ($response -eq "A".ToUpper()) {
    Erase-Baseline-If-Already-Exists

    Create-Baseline
}
elseif ($response -eq "B".ToUpper()) {
    $baselineExists = Test-Path -Path $baselineName #.\baseline.txt

    if (-not $baselineExists) {
        Create-Baseline
    }

    $fileHashDictionary = Make-Baseline-Dictionary

    [bool] $monitor = 1

    while ($monitor) {
        Start-Sleep -Seconds 1
        
        $files = Get-ChildItem -Path $folderPath

        foreach ($f in $files) {
            $hash = Calculate-File-Hash $f.FullName

            if ($fileHashDictionary[$hash.Path] -eq $null) {
                Write-Host "$($hash.Path) has been created!" -ForegroundColor Green

                $authorise = Authorise-Or-View-Change $hash.Path
                $monitor, $reassess = $authorise, $authorise

                if ($reassess) {
                    Erase-Baseline-If-Already-Exists
                    Create-Baseline
                    $fileHashDictionary = Make-Baseline-Dictionary
                }
            }
            else {
                if ($fileHashDictionary[$hash.Path] -eq $hash.Hash) {
                }
                else {
                    Write-Host "$($hash.Path) has changed!!!" -ForegroundColor Yellow
                    $authorise = Authorise-Or-View-Change $hash.Path
                    $monitor, $reassess = $authorise, $authorise

                    if ($reassess) {
                        Erase-Baseline-If-Already-Exists
                        Create-Baseline
                        $fileHashDictionary = Make-Baseline-Dictionary
                    }
                }
            }
        }

        foreach ($key in $fileHashDictionary.Keys) {
            $baselineFileStillExists = Test-Path -Path $key
            if (-Not $baselineFileStillExists) {
                Write-Host "$($key) has been deleted!" -ForegroundColor DarkRed -BackgroundColor Gray
                
                $authorise = Authorise-Or-View-Change $folder
                $monitor, $reassess = $authorise, $authorise

                if ($reassess) {
                    Erase-Baseline-If-Already-Exists
                    Create-Baseline
                    $fileHashDictionary = Make-Baseline-Dictionary
                }
            }
        }
    }
}