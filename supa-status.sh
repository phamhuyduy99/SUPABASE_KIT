#!/bin/bash
# ==============================================
# STATUS.SH – Kiểm tra container Supabase
# ==============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

echo -e "${BOLD_BLUE}📊 Trạng thái các container:${NC}"
if command -v docker &> /dev/null; then
    # Lấy danh sách container và định dạng với màu sắc
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | while IFS= read -r line; do
        if [[ "$line" == *"Up"* ]]; then
            echo -e "${BOLD_GREEN}$line${NC}"
        else
            echo "$line"
        fi
    done
else
    echo -e "${BOLD_RED}Docker chưa được cài hoặc không có container nào.${NC}"
fi