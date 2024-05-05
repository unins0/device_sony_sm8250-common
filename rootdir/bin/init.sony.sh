#!/vendor/bin/sh
ltapath="/dev/block/bootdevice/by-name/LTALabel"
model=`grep -aim1 'model:' "$ltapath" | sed -e 's/^.*model:[ ]*\([A-Za-z0-9-]*\).*$/\1/I'` 2> /dev/null

case "$model" in
    "XQ-AT42" | "XQ-AT52" | "XQ-AT72" | "XQ-AS42" | "XQ-AS52" | "XQ-AS62" | "XQ-AS72" )
        setprop vendor.radio.multisim.config dsds;;
    * )
        setprop vendor.radio.multisim.config ss;;
esac

# If the model string is empty redo a check for carrier models and set it as the model.
if [ -z "$model" ]; then
    model=`awk -F'<b>' '/<b>/ {gsub(/<\/?[^>]+(>|$)/, "", $2); gsub(/&nbsp;/, "", $2); if (match($2, /SOG02|SOG01|SO-52A|SO-51A|A002SO/)) {print substr($2, RSTART, RLENGTH); exit}}' "$ltapath"`
fi

case "$model" in
    "XQ-AT42" | "XQ-AS42" | "A002SO" | "SOG01" | "SOG02" | "SO-51A" | "SO-52A" )
        setprop persist.vendor.nfc.config_file_name "libnfc-nxp-typef.conf";;
    * )
        setprop persist.vendor.nfc.config_file_name "libnfc-nxp.conf"
esac
