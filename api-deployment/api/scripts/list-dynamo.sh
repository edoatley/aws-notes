aws dynamodb list-tables \
    --region eu-west-2 | jq -r '.TableNames[]' | \
    while read -r table; do
        echo "----------------------------------------"
        echo "Table: $table"
        echo "----------------------------------------"
        aws dynamodb describe-table --table-name "$table" --region eu-west-2 | jq '.'
        echo "----------------------------------------"
    done
echo ""
echo "----------------------------------------"
echo "All tables listed."
echo "----------------------------------------"
