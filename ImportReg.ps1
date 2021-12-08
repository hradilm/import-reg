function numberArray2unicodeString {
    param (
        $numberArray
    )

    $charCode = ""
    $string = ""
    [string[]]$mstring = @()
    foreach ($byte in $numberArray.Split(",")) {
        $charCode = $byte + $charCode
        if ($charCode.Length -eq 4) {
            if ([int]$charCode -eq 0) {
                if ($string) {
                    $mstring += $string
                    $string = ""
                }
            } else {
                $string += [char] [int] ("0x" + $charCode)
            }
            $charCode = ""
        }
    }

    Write-Output $mstring
}

$regFile = $args[0]

$regList = Get-Content -Path $regFile

$path = ""
$key = ""
$value = ""

foreach ($line in $regList) {
    if ($line[0] -eq "[") {
        $path = $line.Substring(1, $line.Length-2)
        $path = $path.Replace("HKEY_LOCAL_MACHINE", "HKLM:")
    } else {
        if ($path -and $line) {
            $key,$value= $line -split "="
            # strip quotations
            $key = $key.Substring(1, $key.Length-2)
            $type = $value -split ":"
            $dummy,$splitValue = $value -split ":"
            $regValue = $null
            try {
                Switch ($type[0]) {
                    "dword" {
                        $regType = "DWord"
                        [int32]$regValue = "0x"+$splitValue
                    }
                    "hex" {
                        $regType = "Binary"
                        [byte[]]$regValue = @()
                        foreach ($byte in $splitValue.Split(",")) {
                            $regValue = $regValue + [uint32]("0x"+$byte)
                        }
                    }
                    "hex(b)" {
                        $regType = "Qword"
                        $number = ""
                        foreach ($byte in $splitValue.Split(",")) {
                            $number = $byte + $number
                        }

                        [uint64]$regValue = "0x"+$number
                    }
                    "hex(7)" {
                        $regType = "MultiString"
                        [string[]]$regValue = numberArray2unicodeString $splitValue
                    }
                    "hex(2)" {
                        $regType = "ExpandString"
                        [string]$regValue = numberArray2unicodeString $splitValue
                    }
                    Default {
                        $regType = "String"
                        # strip quotations
                        [string]$regValue = $value.Substring(1, $value.Length-2)
                    }
                }
            } catch {
                $message = $_
                Write-Host "!!! Error when processing !!!`nPath:${path}`nKey:${key}`n$message"
            }

            if(!(Test-Path $path)) {
                New-Item -Path $path -Force
            }
            try {
                Set-ItemProperty -Path $path -Name $key -Value $regValue -Type $regType -Force
            } catch {
                $message = $_
                Write-Host "!!! Error when setting !!!`nPath:${path}`nKey:${key}`nValue:${regValue}`n$message"
            }
        }
    }
}