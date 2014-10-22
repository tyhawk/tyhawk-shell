# http://stackoverflow.com/questions/20700620/convert-massive-mysql-dump-file-to-csv
/^INSERT/ {
    line=$0
    while (match (line,/[^(]*\(([^)]*)\)/,a)) {
        cur=a[1]
        sub(/^['"]/,"",cur)
        sub(/['"]$/,"",cur)
        print cur
        line=substr(line,RSTART+RLENGTH)
    }
}
