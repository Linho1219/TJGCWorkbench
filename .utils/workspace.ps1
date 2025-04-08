function makedata {
    # 生成测试数据文件
    param (
        [string]$outputPrefix = "default",
        [int]$tot = 15
    )

    $output = "$outputPrefix-data.txt"
    $content = @("[demo]", "$outputPrefix-demo.exe", "[tot]", "$tot", "")
    foreach ($i in 1..$tot) {
        $content += "[$i]"
        $content += ""
        $content += ""
    }
    [System.IO.File]::WriteAllLines($output, $content)
    Write-Host "已生成测试配置 $output。" -ForegroundColor Green
    code $output
}

function ensuredir {
    # 确保目录存在，如果不存在则创建
    param (
        [string]$dirPath
    )
    if (-not (Test-Path $dirPath)) {
        New-Item -Path $dirPath -ItemType Directory | Out-Null
    }
}

function compvc {
    # 使用 VC 编译器编译 C++ 文件
    param (
        [string]$inputFile,
        [string]$outputFile = "debug/dump/ownvc.exe",
        [switch]$srcgbk,
        [switch]$ignoreWarnings
    )

    Write-Host "使用 VC 编译 $inputFile 到 $outputFile" -ForegroundColor DarkGray
    ensuredir "debug"
    ensuredir "debug/dump"
    $sourceCharset = if ($srcgbk) { "gbk" } else { "UTF-8" }

    # cl 第一行会输出文件名，跳过
    if ($ignoreWarnings) {
        cl /permissive- /Zc:inline /fp:precise /nologo /W3 /WX- /Zc:forScope /RTC1 /Gd /Oy- /MDd /FC /EHsc /sdl /GS /diagnostics:column /source-charset:$sourceCharset /execution-charset:GBK /Fe:$outputFile $inputFile | Select-Object -Skip 1 | Out-Default
    }
    else {
        cl /permissive- /Zc:inline /fp:precise /nologo /W3 /WX /Zc:forScope /RTC1 /Gd /Oy- /MDd /FC /EHsc /sdl /GS /diagnostics:column /source-charset:$sourceCharset /execution-charset:GBK /Fe:$outputFile $inputFile | Select-Object -Skip 1 | Out-Default
    }
    $vcError = $LASTEXITCODE

    if ($vcError -eq 0) {
        Remove-Item *.obj -Force
    }
    else {
        if ($ignoreWarnings) {
            Write-Host "VC 编译有错误！" -ForegroundColor Red
        }
        else {
            Write-Host "VC 编译有警告或错误！" -ForegroundColor Red
        }
    }
    return $vcError
}

function compgcc {
    # 使用 GCC 编译器编译 C++ 文件
    param (
        [string]$inputFile,
        [string]$outputFile = "debug/dump/owngcc.exe",
        [switch]$srcgbk,
        [switch]$ignoreWarnings
    )

    Write-Host "使用 GCC 编译 $inputFile 到 $outputFile" -ForegroundColor DarkGray
    ensuredir "debug"
    ensuredir "debug/dump"
    $inputCharset = if ($srcgbk) { "GBK" } else { "UTF-8" }
    if ($ignoreWarnings) {
        g++ $inputFile -o $outputFile -finput-charset="$inputCharset" -fexec-charset=gbk | Out-Default
    }
    else {
        g++ $inputFile -o $outputFile -finput-charset="$inputCharset" -fexec-charset=gbk -Werror | Out-Default
    }
    $gccError = $LASTEXITCODE

    if ($gccError -ne 0) {
        if ($ignoreWarnings) {
            Write-Host "GCC 编译有错误！" -ForegroundColor Red
        }
        else {
            Write-Host "GCC 编译有警告或错误！" -ForegroundColor Red
        }
    }
    return $gccError
}

function runvc {
    # 编译运行 VC
    param (
        [string]$ownCpp
    )

    $ownVcExe = "debug/dump/ownvc.exe"
    $vcError = compvc -inputFile $ownCpp -outputFile $ownVcExe -ignoreWarnings
    Write-Host ""
    if ($vcError -eq 0) {
        & .\$ownVcExe
    }
}

function rungcc {
    # 编译运行 GCC
    param (
        [string]$ownCpp
    )
    $ownGccExe = "debug/dump/owngcc.exe"
    $gccError = compgcc -inputFile $ownCpp -outputFile $ownGccExe -ignoreWarnings
    Write-Host ""
    if ($gccError -eq 0) {
        & .\$ownGccExe
    }
}

function owngcc {
    # 运行 GCC 产物
    if (-not (Test-Path "debug/dump/owngcc.exe")) {
        Write-Host "未找到 debug/dump/owngcc.exe。请先编译。" -ForegroundColor Red
        return
    }
    else {
        & "debug/dump/owngcc.exe"
    }
}

function ownvc {
    # 运行 VC 产物
    if (-not (Test-Path "debug/dump/ownvc.exe")) {
        Write-Host "未找到 debug/dump/ownvc.exe。请先编译。" -ForegroundColor Red
        return
    }
    else {
        & "debug/dump/ownvc.exe"
    }
}

function test {
    # 完整测试
    # eg test 4-b2 -2.cpp
    # eg test 4-b2 .c -chkout
    param (
        [string]$dataSrcPrefix, # 数据文件前缀
        [string]$ownCpp, # 源文件
        [switch]$chkout
    )
    $ownCpp = "$dataSrcPrefix$ownCpp"
    if ($chkout) {
        $ownCpp = "output/$ownCpp"
    }
    $dataSrc = "$dataSrcPrefix-data.txt"
    $dataPrefix = ""
    $ownGccExe = "debug/dump/owngcc.exe"
    $ownVcExe = "debug/dump/ownvc.exe"
    $gccResPath = "debug/dump/resgcc.txt"
    $vcResPath = "debug/dump/resvc.txt"
    $demoResPath = "debug/dump/resdemo.txt"

    $gccConflictPath = "debug/conflictgcc.txt"
    $vcConflictPath = "debug/conflictvc.txt"
    $demoConflictPath = "debug/conflictdemo.txt"

    $dataNum = & getinput $dataSrc "[tot]"
    if (-not $dataNum) { $dataNum = 0 }

    if ($dataNum -ne 0) {
        $demoExe = & getinput $dataSrc "[demo]"
        Write-Host "使用 demo 程序 $demoExe，数据组数 $dataNum。"
        $trim = & getinput $dataSrc "[trim]" 2>$null
        $maxlineStr = & getinput $dataSrc "[maxline]" 2>$null
        if ($maxlineStr) {
            $maxline = [int]$maxlineStr
            if ($maxline -le 0) {
                $maxline = 0
            }
        }
        else {
            $maxline = 0
        }
    }
    else {
        Write-Host "未读取到数据。仅编译不比对。"
    }

    $gccErr = compgcc -inputFile $ownCpp -outputFile $ownGccExe -srcgbk:($chkout)
    $vcErr = compvc -inputFile $ownCpp -outputFile $ownVcExe -srcgbk:($chkout)

    if ($gccErr -ne 0 -or $vcErr -ne 0) { return }
    if ($dataNum -eq 0) {
        Write-Host "编译通过。`n" -ForegroundColor Green
        return
    }

    "" | Out-File $gccResPath
    "" | Out-File $vcResPath
    "" | Out-File $demoResPath

    $barWidth = 45  # 进度条宽度
    Write-Host -NoNewline ""

    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $resultTitle = "测试时间  $time`n编译文件  $ownCpp`n数据源    $dataSrc`n组数      $dataNum`n"
    $demoOutputs = @($resultTitle)
    $vcOutputs = @($resultTitle)
    $gccOutputs = @($resultTitle)

    $demoConflicts = @($resultTitle)
    $vcConflicts = @($resultTitle)
    $gccConflicts = @($resultTitle)

    $conflictCount = 0
    $vcgccdiff = $false
    for ($i = 1; $i -le $dataNum; $i++) {
        $inputData = & getinput $dataSrc "[$dataPrefix$i]"

        $demoSigleArr = $inputData | & "./$demoExe" 2>&1
        $vcSingleArr = $inputData | & "./$ownVcExe" 2>&1
        $gccSingleArr = $inputData | & "./$ownGccExe" 2>&1

        if ($trim -eq "right") {
            $demoSigleArr = ($demoSigleArr | ForEach-Object { $_.TrimEnd() })
            $vcSingleArr = ($vcSingleArr | ForEach-Object { $_.TrimEnd() })
            $gccSingleArr = ($gccSingleArr | ForEach-Object { $_.TrimEnd() })
        }
        if ($maxline) {
            $demoSigleArr = $demoSigleArr | Select-Object -First $maxline
            $vcSingleArr = $vcSingleArr | Select-Object -First $maxline
            $gccSingleArr = $gccSingleArr | Select-Object -First $maxline
        }

        $demoSigle = $demoSigleArr -join "`n"
        $vcSingle = $vcSingleArr -join "`n"
        $gccSingle = $gccSingleArr -join "`n"

        $demoOutputs += "[$i]"
        $demoOutputs += $demoSigle
        $vcOutputs += "[$i]"
        $vcOutputs += $vcSingle
        $gccOutputs += "[$i]"
        $gccOutputs += $gccSingle

        if ($demoSigle -ne $vcSingle -or $demoSigle -ne $gccSingle) {
            $conflictCount++
            $demoConflicts += "[$i Input]"
            $demoConflicts += $inputData
            $demoConflicts += "[$i Output]"
            $demoConflicts += $demoSigle

            $vcConflicts += "[$i Input]"
            $vcConflicts += $inputData
            $vcConflicts += "[$i Output]"
            $vcConflicts += $vcSingle

            $gccConflicts += "[$i Input]"
            $gccConflicts += $inputData
            $gccConflicts += "[$i Output]"
            $gccConflicts += $gccSingle

            if ($vcSingle -ne $gccSingle) {
                $vcgccdiff = $true
            }
        }

        $percent = [math]::Round(($i / $dataNum) * 100)
        $filled = [math]::Round(($i / $dataNum) * $barWidth)
        $empty = $barWidth - $filled
        if ($conflictCount -ne 0) {
            $conflict = [math]::Round(($conflictCount / $dataNum) * $barWidth)
            $filled = $filled - $conflict
            Write-Host -NoNewline "`r["
            $redbar = ("=" * $conflict)
            $normalbar = ("=" * $filled) + (" " * $empty) + "] $percent%"
            Write-Host -NoNewline $redbar -ForegroundColor Red
            Write-Host -NoNewline $normalbar
        }
        else {
            $bar = "[" + ("=" * $filled) + (" " * $empty) + "] $percent%"
            Write-Host -NoNewline "`r$bar"
        }
        [Console]::Out.Flush()
    }

    [System.IO.File]::WriteAllLines($gccResPath, $gccOutputs)
    [System.IO.File]::WriteAllLines($vcResPath, $vcOutputs)
    [System.IO.File]::WriteAllLines($demoResPath, $demoOutputs)

    if ($trim -eq "right") {
        $compareConfig = "忽略行尾空格匹配"
    }
    else {
        $compareConfig = "完全匹配"
    }
    if ($maxline) {
        $compareConfig += "前 $maxline 行"
    }

    if ($conflictCount -ne 0) {
        [System.IO.File]::WriteAllLines($gccConflictPath, $gccConflicts)
        [System.IO.File]::WriteAllLines($vcConflictPath, $vcConflicts)
        [System.IO.File]::WriteAllLines($demoConflictPath, $demoConflicts)

        Write-Host "`n测试完毕。$compareConfig，有 $conflictCount 组冲突。" -ForegroundColor Yellow
        if ($vcgccdiff) {
            code --diff $demoConflictPath $vcConflictPath
            code --diff $demoConflictPath $gccConflictPath
            Write-Host "GCC 和 VC 结果不一致。启动两个比对。" -ForegroundColor Red
        }
        else {
            code --diff $demoConflictPath $vcConflictPath
            Write-Host "启动比对。" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "`n测试完毕。$compareConfig，无冲突。" -ForegroundColor Green
    }
    Write-Host ""
}

function pack {
    # 打包文件到 ./source 文件夹
    if (Test-Path "./source") {
        Write-Host "错误：./source 文件夹已存在！" -ForegroundColor Red
        return
    }

    New-Item -Path "./source" -ItemType Directory | Out-Null
    Move-Item -Path *-data.txt, *-demo.exe, *.cpp, *.c -Destination "./source" -ErrorAction SilentlyContinue
    Write-Host "文件已移动到 ./source 文件夹。" -ForegroundColor Green
}

function unpack {
    # 解包文件到当前目录
    if (-not (Test-Path "./source")) {
        Write-Host "错误：./source 文件夹不存在！" -ForegroundColor Red
        return
    }
    Move-Item -Path "./source/*-data.txt", "./source/*-demo.exe", "./source/*.cpp", "./source/*.c" -Destination "./" -ErrorAction SilentlyContinue
    Remove-Item -Path "./source" -Force
    Write-Host "./source 已解包。" -ForegroundColor Green
}

function listcolors {
    $colors = [enum]::GetValues([System.ConsoleColor])
    Foreach ($bgcolor in $colors) {
        Foreach ($fgcolor in $colors) { Write-Host "$fgcolor|"  -ForegroundColor $fgcolor -BackgroundColor $bgcolor -NoNewLine }
        Write-Host " on $bgcolor"
    }
}

function format {
    & tjformat . -c .utils/tjformat.json5
    $targetFolder = "./output"
    Get-ChildItem -Path $targetFolder -Directory -Recurse |
    Where-Object {
        # 检查文件夹是否为空
        @(Get-ChildItem -Path $_.FullName -Force).Count -eq 0
    } |
    Remove-Item -Force
}

$installkey = & Get-Content "./.utils/.vsinstallkey" 2>$null
if (-not $installkey) {
    # 没有提前设置，尝试从快捷方式中提取
    $shell = New-Object -ComObject WScript.Shell
    $shortcutPath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Visual Studio 2022\Visual Studio Tools\Developer PowerShell for VS 2022.lnk"
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $target = $shortcut.TargetPath
    $arguments = $shortcut.Arguments
    $fullCommand = "$target $arguments"
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
    if ($fullCommand -match 'Enter-VsDevShell\s+([a-f0-9]+)') {
        $installkey = $matches[1]
        Write-Output "未找到 .vsinstallkey，已从快捷方式中自动提取。"
        Write-Output $installkey | Out-File -FilePath "./.utils/.vsinstallkey" -Encoding utf8
    }
    else {
        # 尝试从 VS 实例文件夹中提取
        $instancePath = "C:\ProgramData\Microsoft\VisualStudio\Packages\_Instances"
        $instanceFolders = Get-ChildItem -Path $instancePath -Directory
        $targetFolder = $instanceFolders | Where-Object { $_.Name.Length -eq 8 }
        if ($targetFolder.Count -eq 1) {
            $installkey = $targetFolder.Name
            Write-Output "未找到 .vsinstallkey，已从 VS 实例文件夹中自动提取。"
            Write-Output $installkey | Out-File -FilePath "./.utils/.vsinstallkey" -Encoding utf8
        }
        else {
            # 寄了，提示手动设置
            Write-Host "未找到安装 key，请检查 .utils/.vsinstallkey 文件。" -ForegroundColor Red
            code ./.utils/.vsinstallkey
            Write-Host "你可以在 Developer PowerShell for VS 2022 的快捷方式或终端配置文件中找到。"
            Write-Host "这是一个 8 位 16 进制数，将其填入 .vsinstallkey 文件中，然后重新启动终端。"
            return
        }
    }
}

Write-Host "正在加载 VC++ 环境 ($installkey)"
Import-Module "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Enter-VsDevShell $installkey -SkipAutomaticLocation -DevCmdArguments "-arch=x86 -host_arch=x64" | Out-Null

Write-Host "环境装载完成。`n" -ForegroundColor Green
