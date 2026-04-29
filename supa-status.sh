#!/bin/bash
# ==============================================
# STATUS.SH – Kiểm tra container Supabase
# ==============================================

echo "📊 Trạng thái các container:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Docker chưa được cài hoặc không có container nào."