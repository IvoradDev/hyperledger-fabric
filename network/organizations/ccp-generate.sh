#!/bin/bash
#
# Generates connection profile JSON and YAML for each org.
# The Node.js SDK uses these files to know how to connect to each org's peer and CA.
# Called at the end of createOrgs() in network.sh.

function one_line_pem {
  echo "`awk 'NF {sub(/\\n/, ""); printf "%s\\\\\\\n",$0;}' $1`"
}

function json_ccp {
  local PP=$(one_line_pem $4)
  local CP=$(one_line_pem $5)
  sed -e "s/\${ORG}/$1/" \
      -e "s/\${P0PORT}/$2/" \
      -e "s/\${CAPORT}/$3/" \
      -e "s#\${PEERPEM}#$PP#" \
      -e "s#\${CAPEM}#$CP#" \
      organizations/ccp-template.json
}

function yaml_ccp {
  local PP=$(one_line_pem $4)
  local CP=$(one_line_pem $5)
  sed -e "s/\${ORG}/$1/" \
      -e "s/\${P0PORT}/$2/" \
      -e "s/\${CAPORT}/$3/" \
      -e "s#\${PEERPEM}#$PP#" \
      -e "s#\${CAPEM}#$CP#" \
      organizations/ccp-template.yaml | sed -e $'s/\\\\n/\\\n          /g'
}

# Generate connection profile for each org (1, 2, 3)
# P0PORT = port of peer0 for that org: org1=7051, org2=8051, org3=9051
# CAPORT = port of CA for that org:    org1=7054, org2=8054, org3=9054
for (( i=1; i<=$1; i++ )); do
  ORG=$i
  P0PORT="$(($i * 1000 + 6051))"
  CAPORT="$(($i * 1000 + 6054))"
  PEERPEM=organizations/peerOrganizations/org${i}.example.com/tlsca/tlsca.org${i}.example.com-cert.pem
  CAPEM=organizations/peerOrganizations/org${i}.example.com/ca/ca.org${i}.example.com-cert.pem

  echo "$(json_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" > organizations/peerOrganizations/org${i}.example.com/connection-org${i}.json
  echo "$(yaml_ccp $ORG $P0PORT $CAPORT $PEERPEM $CAPEM)" > organizations/peerOrganizations/org${i}.example.com/connection-org${i}.yaml
done
