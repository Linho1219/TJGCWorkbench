function tjformat {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$SourceDir,

        [Parameter()]
        [string]$OutputDir = "./output",

        [Parameter()]
        [int]$Depth = 3,

        [Parameter()]
        [string]$ConfigPath = "./.utils/tjformat.json"
    )

    begin {
        # Resolve paths to absolute to avoid relative path issues
        $SourceDir = Resolve-Path -Path $SourceDir -ErrorAction Stop
        $OutputDir = [System.IO.Path]::GetFullPath($OutputDir)
        $ConfigPath = [System.IO.Path]::GetFullPath($ConfigPath)

        # Validate inputs
        if (-not (Test-Path -Path $SourceDir -PathType Container)) {
            Write-Error "Source directory '$SourceDir' does not exist."
            return
        }
        if (-not (Test-Path -Path $ConfigPath -PathType Leaf)) {
            Write-Error "Config file '$ConfigPath' does not exist."
            return
        }
        if (-not (Test-Path -Path "./.utils/tjformat.clang-format" -PathType Leaf)) {
            Write-Error "Clang-format config './.utils/tjformat.clang-format' does not exist."
            return
        }
        if (-not (Get-Command -Name "clang-format" -ErrorAction SilentlyContinue)) {
            Write-Error "clang-format is not installed or not in PATH."
            return
        }

        # Read and parse JSON config
        try {
            $config = Get-Content -Path $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to parse config file '$ConfigPath': $_"
            return
        }

        # Validate config properties
        $requiredProps = @("ExtraReplaces", "FormatBasenames", "CopyBasenames", "PrefixContent", "ReplaceMacro")
        foreach ($prop in $requiredProps) {
            if (-not $config.PSObject.Properties.Name -contains $prop) {
                Write-Error "Config file missing required property '$prop'."
                return
            }
        }

        # Extract config values
        $ExtraReplaces = $config.ExtraReplaces
        $FormatBasenames = $config.FormatBasenames
        $CopyBasenames = $config.CopyBasenames
        $PrefixContent = $config.PrefixContent
        $ReplaceMacro = $config.ReplaceMacro
    }

    process {
        # Remove output directory if it exists
        if (Test-Path -Path $OutputDir) {
            Remove-Item -Path $OutputDir -Recurse -Force -ErrorAction Stop
        }
        New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null

        # Function to read file (UTF-8, normalize to LF)
        function Read-SourceFile {
            param ([string]$Path)
            $content = Get-Content -Path $Path -Raw -Encoding UTF8
            return $content -replace "`r`n", "`n"
        }

        # Function to write file (GBK, CRLF)
        function Write-OutputFile {
            param (
                [string]$Path,
                [string]$Content
            )
            # Write as GBK (OEM encoding in PowerShell approximates GBK)
            [System.IO.File]::WriteAllText($Path, $Content, [System.Text.Encoding]::GetEncoding("GBK"))
        }

        # Function to format code
        function Format-Code {
            param ([string]$Code)

            # Step 1: Apply extra regex replacements
            foreach ($replace in $ExtraReplaces) {
                $pattern = $replace[0]
                $replacement = $replace[1]
                $Code = $Code -replace $pattern, $replacement
            }

            # Step 2: Replace macros if enabled
            if ($ReplaceMacro) {
                # Find all #define lines
                $macroMatches = [regex]::Matches($Code, '(?<=^|\n)#define +(\w+) +([^\n]+)(?=\n)') | Sort-Object Index -Descending
                $processedCode = $Code
                foreach ($match in $macroMatches) {
                    $macroName = $match.Groups[1].Value
                    $macroValue = $match.Groups[2].Value
                    $macroLine = $match.Groups[0].Value
                    # Remove the #define line
                    $processedCode = $processedCode -replace [regex]::Escape($macroLine), ""
                    # Replace macro occurrences (word boundaries)
                    $processedCode = $processedCode -replace "\b$macroName\b", $macroValue
                }
                $Code = $processedCode
            }

            # Step 3: Run clang-format
            try {
                # Write code to a temp file
                $tempFile = [System.IO.Path]::GetTempFileName()
                Set-Content -Path $tempFile -Value $Code -Encoding GBK

                # Run clang-format with the specified config
                $formattedCode = clang-format -style="file:./.utils/tjformat.clang-format" $tempFile | Out-String

                # Clean up temp file
                Remove-Item -Path $tempFile -Force

                # Step 4: Prepend prefix content
                $finalCode = ($PrefixContent -join "`n") + "`n" + $formattedCode.TrimEnd()

                return $finalCode
            }
            catch {
                Write-Warning "Failed to format code: $_"
                return $Code
            }
        }

        # Process directory recursively
        function Format-Directory {
            param (
                [string]$InputDir,
                [string]$OutputDir,
                [int]$MaxDepth,
                [int]$CurrentDepth = 0
            )

            if ($CurrentDepth -gt $MaxDepth) {
                return
            }

            # Create output directory
            if (-not (Test-Path -Path $OutputDir)) {
                New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
            }

            # Get directory contents
            Get-ChildItem -Path $InputDir -ErrorAction Stop | ForEach-Object {
                $inputPath = $_.FullName
                $relativePath = $inputPath.Substring($SourceDir.Length + 1)
                $outputPath = Join-Path -Path $OutputDir -ChildPath $relativePath

                # Skip output directory
                if ($inputPath -like "*$OutputDir*") {
                    return
                }
                if ($inputPath -like "*debug" -or $inputPath -like "*.vscode" -or $inputPath -like "*.utils") {
                    return
                }

                if ($_.PSIsContainer) {
                    # Recurse into subdirectory
                    Format-Directory -InputDir $inputPath -OutputDir $outputPath -MaxDepth $MaxDepth -CurrentDepth ($CurrentDepth + 1)
                }
                else {
                    $extension = $_.Extension.TrimStart('.').ToLower()
                    if ($FormatBasenames -contains $extension) {
                        Write-Host "处理文件 $($_.Name)"
                        try {
                            $code = Read-SourceFile -Path $inputPath
                            $formattedCode = Format-Code -Code $code
                            Write-OutputFile -Path $outputPath -Content $formattedCode
                        }
                        catch {
                            Write-Warning "Failed to process file '$($_.Name)': $_"
                        }
                    }
                    elseif ($CopyBasenames -contains $extension) {
                        Write-Host "复制文件 $($_.Name)"
                        try {
                            Copy-Item -Path $inputPath -Destination $outputPath -Force
                        }
                        catch {
                            Write-Warning "Failed to copy file '$($_.Name)': $_"
                        }
                    }
                }
            }
        }

        # Start processing
        try {
            Format-Directory -InputDir $SourceDir -OutputDir $OutputDir -MaxDepth $Depth
            Write-Host "处理完成。"
        }
        catch {
            Write-Error "Processing failed: $_"
        }
    }
}