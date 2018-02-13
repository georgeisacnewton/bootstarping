#!/bin/bash
set -e

[ -z "$BOOTSTRAP_URL" ] && export BOOTSTRAP_URL='http://bootstrap.services.dmtio.net/v1/get_bootstrap'

usage() {
    echo "usage: $0 -c chassis -f package_size -l location -D destination [-u CUSTOMER] [-n network] [-m mkfs_opts] [-v lvm_opts]" >&2
    echo "       -c {VMWARE_VIRTUAL | AEROSOL_VIRTUAL | DELL_R710 | DELL_R720} " >&2
    echo "       -f {2x4x8-vmw | 32x192x10000-phys | ...}" >&2
    echo "       -l {cop|56m|lax}" >&2
    echo "       -u {CUSTOMER} " >&2
    echo "       -n {SHARED|PROD} " >&2
    echo "       -m mkfs {xvdb,/mnt} " >&2
    echo "       -v lvm {xvdb,xvdc:vg0/data} " >&2
    echo "       -D scp the script to destination e.g. remotehost:~/argo-bootstrap.sh" >&2
    echo "          -D /root/user-script also works" >&2
    exit 1
}

while getopts "u:c:f:l:D:n:v:m:p:h" arg; do
    case $arg in
        u)
            CUSTOMER=$OPTARG
            ;;
        c)
            CHASSIS=$OPTARG
            ;;
        f)
            FLAVOR=$OPTARG
            ;;
        l)
            LOCATION=$OPTARG
            ;;
        D)
            DEST=$OPTARG
            ;;
        n)
            NETWORK=$OPTARG
            ;;
        m)
            MKFS="$OPTARG"
            ;;
        v)
            LVM="$OPTARG"
            ;;
        p)
            PRODUCTS="$OPTARG"
            ;;
        h)
            usage
            ;;
    esac
done

[ -z "$CHASSIS" -o -z "$LOCATION" -o -z "$FLAVOR" -o -z "$DEST" ] && usage
[ -z "$USER" ] && USER=ictops
[ -z "$PRODUCTS" ] && PRODUCTS=base:shared
[ -z "$CUSTOMER" ] && CUSTOMER=ictops
[ -z "$NETWORK" ] && NETWORK=SHARED
CONFTAG=$NETWORK

cat > /tmp/argo-bootstrap.json.$$ << EOP
{"chassis":"$CHASSIS",
"package":"$FLAVOR",
"location":"$LOCATION",
"owner":"ictops",
"customer":"$CUSTOMER",
"network":"$NETWORK",
"conftag":"SHARED",
"creator":"$USER",
"mkfs":"$MKFS",
"lvm":"$LVM",
"products":[]
}
EOP

err=$(curl -s -H "Content-Type: application/json" --data-binary @/tmp/argo-bootstrap.json.$$ $BOOTSTRAP_URL | jq .error)
if [ "$err" = "false" ]; then
 curl -s -H "Content-Type: application/json" --data-binary @/tmp/argo-bootstrap.json.$$ $BOOTSTRAP_URL | jq -r .bootstrap > /tmp/argo-bootstrap.sh.$$
else
 echo "BOOTSTRAP-API: error not false - $err"
 exit 2
fi

scp -q /tmp/argo-bootstrap.sh.$$ $DEST && echo "$DEST created"
rm /tmp/argo-bootstrap.json.$$
rm /tmp/argo-bootstrap.sh.$$
 
