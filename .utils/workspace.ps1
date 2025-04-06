Write-Host "正在加载 VC++ 环境..."
Import-Module "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
Enter-VsDevShell 8825af93 -SkipAutomaticLocation -DevCmdArguments "-arch=x86 -host_arch=x64" | Out-Null

function makedata {
    # 生成测试数据文件
    param (
        [string]$outputPrefix = "default",
        [int]$tot = 10
    )

    $output = "$outputPrefix-data.txt"

    $content = @("[demo]", "$outputPrefix-demo.exe", "[tot]", "$tot", "")
    foreach ($i in 1..$tot) {
        $content += "[$i]"
        $content += ""
        $content += ""
    }
    [System.IO.File]::WriteAllLines($output, $content)

    Write-Host "完成。" -ForegroundColor Green

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
        [string]$outputFile = "debug/ownvc.exe",
        [switch]$srcgbk,
        [switch]$ignoreWarnings
    )

    Write-Host "使用 VC 编译 $inputFile 到 $outputFile" -ForegroundColor DarkBlue
    ensuredir "debug"
    $sourceCharset = if ($srcgbk) { "gbk" } else { "UTF-8" }
    if ($ignoreWarnings) {
        cl /permissive- /Zc:inline /fp:precise /nologo /W3 /WX- /Zc:forScope /RTC1 /Gd /Oy- /MDd /FC /EHsc /sdl /GS /diagnostics:column /source-charset:$sourceCharset /execution-charset:GBK /Fe:$outputFile $inputFile | Out-Default
    }
    else {
        cl /permissive- /Zc:inline /fp:precise /nologo /W3 /WX /Zc:forScope /RTC1 /Gd /Oy- /MDd /FC /EHsc /sdl /GS /diagnostics:column /source-charset:$sourceCharset /execution-charset:GBK /Fe:$outputFile $inputFile | Out-Default
    }
    $vcError = $LASTEXITCODE

    if ($vcError -eq 0) {
        Remove-Item *.obj -Force
    }
    else {
        if ($ignoreWarnings) {
            Write-Host "VC 编译有错误！" -ForegroundColor Red
        } else {
            Write-Host "VC 编译有警告或错误！" -ForegroundColor Red
        }
    }
    return $vcError
}

function compgcc {
    # 使用 GCC 编译器编译 C++ 文件
    param (
        [string]$inputFile,
        [string]$outputFile = "debug/owngcc.exe",
        [switch]$srcgbk,
        [switch]$ignoreWarnings
    )

    Write-Host "使用 GCC 编译 $inputFile 到 $outputFile" -ForegroundColor DarkBlue
    ensuredir "debug"
    $inputCharset = if ($srcgbk) { "GBK" } else { "UTF-8" }
    if ($ignoreWarnings) {
        g++ $inputFile -o $outputFile -finput-charset="$inputCharset" -fexec-charset=gbk | Out-Default
    }
    else {
        g++ $inputFile -o $outputFile -finput-charset="$inputCharset" -fexec-charset=gbk -Werror | Out-Default
    }
    $gccError = $LASTEXITCODE

    if ($gccError -ne 0) {
        if($ignoreWarnings) {
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

    $ownVcExe = "debug/ownvc.exe"
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
    $ownGccExe = "debug/owngcc.exe"
    $gccError = compgcc -inputFile $ownCpp -outputFile $ownGccExe -ignoreWarnings
    Write-Host ""
    if ($gccError -eq 0) {
        & .\$ownGccExe
    }
}

function owngcc {
    # 运行 GCC 产物
    if (-not (Test-Path "debug/owngcc.exe")) {
        Write-Host "未找到 debug/owngcc.exe。请先编译。" -ForegroundColor Red
        return
    }
    else {
        & "debug/owngcc.exe"
    }
}

function ownvc {
    # 运行 VC 产物
    if (-not (Test-Path "debug/ownvc.exe")) {
        Write-Host "未找到 debug/ownvc.exe。请先编译。" -ForegroundColor Red
        return
    }
    else {
        & "debug/ownvc.exe"
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
    $ownGccExe = "debug/owngcc.exe"
    $ownVcExe = "debug/ownvc.exe"
    $ownGccRes = "debug/resgcc.txt"
    $ownVcRes = "debug/resvc.txt"
    $demoRes = "debug/resdemo.txt"

    $dataNum = & getinput $dataSrc "[tot]"
    if (-not $dataNum) { $dataNum = 0 }

    if ($dataNum -ne 0) {
        Write-Host "读取到 $dataNum 组数据。"
        $demoExe = & getinput $dataSrc "[demo]"
        Write-Host "使用 demo 程序 $demoExe。"
    }
    else {
        Write-Host "未读取到数据。仅编译不比对。"
    }

    Write-Host "编译文件：$ownCpp"

    $gccErr = compgcc -inputFile $ownCpp -outputFile $ownGccExe -srcgbk:($chkout)
    if ($gccErr -eq 0) {
        Write-Host "GCC 编译通过。" -ForegroundColor Green
    }

    $vcErr = compvc -inputFile $ownCpp -outputFile $ownVcExe -srcgbk:($chkout)
    if ($vcErr -eq 0) {
        Write-Host "VC 编译通过。" -ForegroundColor Green
    }

    if ($dataNum -eq 0) { return }

    if ($gccErr -ne 0 -or $vcErr -ne 0) { return }

    "" | Out-File $ownGccRes
    "" | Out-File $ownVcRes
    "" | Out-File $demoRes

    $barWidth = 45  # 进度条宽度
    Write-Host -NoNewline "进度: "

    for ($i = 1; $i -le $dataNum; $i++) {
        $percent = [math]::Round(($i / $dataNum) * 100)
        $filled = [math]::Round(($i / $dataNum) * $barWidth)
        $empty = $barWidth - $filled
        $bar = "[" + ("=" * $filled) + (" " * $empty) + "] $percent%"

        Write-Host -NoNewline "`r进度: $bar"  # 使用 `r` 回到行首覆盖
        [Console]::Out.Flush()  # 强制刷新输出

        "[$i]" | Out-File -Append $ownGccRes
        "[$i]" | Out-File -Append $ownVcRes
        "[$i]" | Out-File -Append $demoRes

        & getinput $dataSrc "[$dataPrefix$i]" | & "./$ownGccExe" | Out-File -Append $ownGccRes 2>&1
        & getinput $dataSrc "[$dataPrefix$i]" | & "./$ownVcExe"  | Out-File -Append $ownVcRes  2>&1
        & getinput $dataSrc "[$dataPrefix$i]" | & "./$demoExe"   | Out-File -Append $demoRes   2>&1
    }
    Write-Host "`n执行完毕。" -ForegroundColor Green
    # 后续代码不变
    Write-Host "GCC 编译产物比较：" -ForegroundColor DarkBlue
    & txtcomp --file1 $demoRes --file2 $ownGccRes --display normal
    Write-Host "VC 编译产物比较：" -ForegroundColor DarkBlue
    & txtcomp --file1 $demoRes --file2 $ownVcRes --display normal
    Write-Host "说明：文件 1 为标解，文件 2 为待测。"

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
        # 检查文件夹是否为空（没有文件和子文件夹）
        @(Get-ChildItem -Path $_.FullName -Force).Count -eq 0
    } |
    Remove-Item -Force
}

Write-Host "环境装载完成。工作区脚本装载完成。" -ForegroundColor Green