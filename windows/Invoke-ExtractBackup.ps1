# ==============================================
# INVOKE-EXTRACTBACKUP.PS1 – Giải nén file backup
# -------------------------------------------------
# Script này giúp giải nén file backup thành thư mục có thể chạy độc lập
# ==============================================

Import-Module .\SupabaseKit.psm1 -Force

Write-Title "GIẢI NÉN BACKUP SUPABASE"

$currentDir = Get-Location
$backupFile = Get-ChildItem -Path $currentDir -Filter "supabase-backup-*.tar.gz" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $backupFile) {
    Write-ErrorMsg "❌ Không tìm thấy file backup .tar.gz trong thư mục hiện tại."
    Write-Info "📁 Các file có trong thư mục hiện tại:"
    Get-ChildItem -Path $currentDir | ForEach-Object { Write-Host "   $($_.Name)" }
    exit 1
}

Write-Info "📦 Đang giải nén: $($backupFile.Name)"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$extractDir = Join-Path $currentDir "$($backupFile.BaseName)_extracted_$timestamp"

try {
    # Tạo thư mục giải nén
    New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
    
    # Kiểm tra có 7-Zip không
    if (Get-Command "7z" -ErrorAction SilentlyContinue) {
        Write-Info "Sử dụng 7-Zip để giải nén..."
        Set-Location $extractDir
        7z x $backupFile.FullName | Out-Null
        Set-Location $currentDir
    } else {
        # Nếu không có 7-Zip, thử đổi tên thành .zip và dùng Expand-Archive
        Write-WarningMsg "Không tìm thấy 7-Zip, đang thử phương pháp thay thế..."
        
        $tempZipPath = $backupFile.FullName -replace '\.tar\.gz$', '.zip'
        Copy-Item -Path $backupFile.FullName -Destination $tempZipPath
        Expand-Archive -Path $tempZipPath -DestinationPath $extractDir
        Remove-Item -Path $tempZipPath -Force
    }
    
    # Kiểm tra kết quả giải nén
    $extractedItems = Get-ChildItem -Path $extractDir
    if ($extractedItems.Count -gt 0) {
        Write-Success "✅ Đã giải nén vào: $extractDir"
        
        # Tìm thư mục backup chính
        $mainBackupDir = $null
        foreach ($item in $extractedItems) {
            if ($item.PSIsContainer -and (Test-Path (Join-Path $item.FullName "backup_data"))) {
                $mainBackupDir = $item.FullName
                break
            }
        }
        
        if ($mainBackupDir) {
            Write-Info "📁 Thư mục chính của backup: $mainBackupDir"
            Write-Info "👉 cd $(Split-Path -Path $mainBackupDir -Leaf) && powershell -ExecutionPolicy Bypass -File Start-SupabaseKit.ps1"
            
            # Hỏi người dùng có muốn di chuyển các file vào thư mục hiện tại không
            $moveFiles = Read-Host "Bạn có muốn di chuyển các file vào thư mục hiện tại không? (y/n)"
            if ($moveFiles -eq 'y') {
                $itemsToMove = Get-ChildItem -Path $mainBackupDir
                foreach ($item in $itemsToMove) {
                    Move-Item -Path $item.FullName -Destination $currentDir
                }
                Write-Success "✅ Đã di chuyển các file vào thư mục hiện tại"
            }
        } else {
            Write-WarningMsg "⚠️ Không tìm thấy thư mục backup_data trong kết quả giải nén"
        }
    } else {
        Write-ErrorMsg "❌ Giải nén thất bại - thư mục trống"
        exit 1
    }
} catch {
    Write-ErrorMsg "❌ Lỗi khi giải nén: $($_.Exception.Message)"
    exit 1
} finally {
    Set-Location $currentDir
}

Write-Success "✅ Giải nén hoàn tất!"