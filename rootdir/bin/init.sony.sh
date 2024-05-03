#!/vendor/bin/sh
ltapath="/dev/block/bootdevice/by-name/LTALabel"
model=`grep -aim1 'model:' "$ltapath" | sed -e 's/^.*model:[ ]*\([A-Za-z0-9-]*\).*$/\1/I'` 2> /dev/null

case "$model" in
    "XQ-AT42" | "XQ-AT52" | "XQ-AT72" | "XQ-AS42" | "XQ-AS52" | "XQ-AS62" | "XQ-AS72" )
        setprop vendor.radio.multisim.config dsds;;
    * )
        setprop vendor.radio.multisim.config ss;;
esac

if [ "$model" == "" ]; then

typef="false"

    # Check if they are japense felica models
    if grep -aim1 "XQ-AS42" "$ltapath" > /dev/null; then
        typef="true"
        setprop vendor.radio.ltalabel.model "XQ-AS42"
    fi
    if grep -aim1 "XQ-AT42" "$ltapath" > /dev/null; then
        typef="true"
        setprop vendor.radio.ltalabel.model "XQ-AT42"
    fi
    if grep -aim1 "SOG02" "$ltapath" > /dev/null; then
        typef="true"
        setprop vendor.radio.ltalabel.model "SOG02"
    fi
    if grep -aim1 "SOG01" "$ltapath" > /dev/null; then
        typef="true"
        setprop vendor.radio.ltalabel.model "SOG01"
    fi
    if grep -aim1 "A002SO" "$ltapath" > /dev/null; then
        typef="true"
        setprop vendor.radio.ltalabel.model "A002SO"
    fi
    if grep -aim1 "SO-52A" "$ltapath" > /dev/null; then
        typef="true"
        setprop vendor.radio.ltalabel.model "SO-52A"
    fi
    if grep -aim1 "SO-51A" "$ltapath" > /dev/null; then
        typef="true"
        setprop vendor.radio.ltalabel.model "SO-51A"
    fi
    if [ ! "$typef" == "true" ]; then
        setprop vendor.radio.ltalabel.model "unknown"
    fi
else
    setprop vendor.radio.ltalabel.model "$model"
fi
