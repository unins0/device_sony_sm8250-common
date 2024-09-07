#!/vendor/bin/sh

model=`grep -am1 '[Mm][Oo][Dd][Ee][Ll]:' /dev/block/bootdevice/by-name/LTALabel | sed -e 's/^.*[Mm][Oo][Dd][Ee][Ll]:[ ]*\([A-Za-z0-9-]*\).*$/\1/'` 2> /dev/null

case "$model" in
    "XQ-AT42" | "XQ-AT52" | "XQ-AT72" | "XQ-AS42" | "XQ-AS52" | "XQ-AS62" | "XQ-AS72" )
        setprop vendor.radio.multisim.config dsds;;
    * )
        setprop vendor.radio.multisim.config ss;;
esac

# If the model string is empty redo a check for carrier models and set it as the model.
if [ -z "$model" ]; then
    model=`awk -F'<b>' '/<b>/ {gsub(/<\/?[^>]+(>|$)/, "", $2); gsub(/&nbsp;/, "", $2); if (match($2, /SOG02|SOG01|SO-52A|SO-51A|A002SO/)) {print substr($2, RSTART, RLENGTH); exit}}' "/dev/block/bootdevice/by-name/LTALabel"`
fi

# Set type-f config for all japense models
case "$model" in
    "XQ-AT42" | "XQ-AS42" | "A002SO" | "SOG01" | "SOG02" | "SO-51A" | "SO-52A" )
        setprop persist.vendor.nfc.config_file_name "libnfc-nxp-typef.conf";;
    * )
        setprop persist.vendor.nfc.config_file_name "libnfc-nxp.conf"
esac
