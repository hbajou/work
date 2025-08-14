$csvData = Import-Csv ".\input.csv"

foreach ($row in $csvData) {
    $action = $row.PSObject.Properties["action"].Value
    $user   = $row.PSObject.Properties["user"].Value

    switch ($action) {
        "ユーザ作成" { Write-Host "【作成】$user を登録します。" }
        "ユーザ削除" { Write-Host "【削除】$user を削除します。" }
        "グループ追加"  { Write-Host "【確認】$user の情報を表示します。" }
        default  { Write-Host "【不明】$user に対する操作 '$action' は未対応です。" }
    }
}