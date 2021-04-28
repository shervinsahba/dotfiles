#!/bin/bash

coins=("BTC" "ETH")
decimal=(0 0)

coinbase_price() {
    coin="$1"
    pair="USD"
    # second argument of zero truncates price to zero decimals. Leave blank otherwise.
    price=$(curl https://api.coinbase.com/v2/prices/$coin-$pair/buy -s \
        -H 'Authorization: Bearer abd90df5f27a7b170cd775abf89d632b350b7c1c9d53e08b340cd9832ce52c2c' \
        | jq '.data.amount' | xargs)
    if [ $2 ]; then price=${price%.*}; fi
    echo $coin $price'  '
}

output=""
i=0
for coin in "${coins[@]}"; do
    output=$output' '$(coinbase_price $coin ${decimal[i]})' '
    i=$((i+1))
done

echo $output
