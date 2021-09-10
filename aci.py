#! env python

import credential
import requests
import json
from requests.packages.urllib3.exceptions import InsecureRequestWarning

# ACI parameters
apicUrl = credential.apicUrl
apicUser = credential.apicUser
apicPassword = credential.apicPassword


def conn(apicUrl="https://192.168.250.151", apicUser="admin", apicPassword="C!sc0123"):
    global apicCookie  # set apicCookie as global variable
    requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

    apicCredential = '<aaaUser name="' + apicUser + '" pwd="' + apicPassword + '" />'
    headers = {"Content-Type": "application/xml"}
    apicLogin = requests.post(
        apicUrl + "/api/aaaLogin.xml",
        data=apicCredential,
        headers=headers,
        verify=False,
    )
    apicCookie = apicLogin.cookies
    return requests.Session()


def list_intf(conn=conn):
    conn = conn()
    nodes = {"pod-1": ["paths-101", "paths-102"], "pod-2": ["paths-121", "paths-122"]}
    intf_list = {}
    for pod in nodes:
        for node in nodes[pod]:
            # print(pod,node)
            list = conn.get(
                apicUrl
                + '/api/node/class/fabricPathEp.json?query-target-filter=and(eq(fabricPathEp.lagT,"not-aggregated"),eq(fabricPathEp.pathT,"leaf"),wcard(fabricPathEp.dn,"topology/'
                + pod
                + "/"
                + node
                + '/"),not(or(wcard(fabricPathEp.name,"^tunnel"),wcard(fabricPathEp.name,"^vfc"))))',
                cookies=apicCookie,
                verify=False,
            )
            node_intf_list = []
            for i in list.json()["imdata"]:
                node_intf_list.append(i["fabricPathEp"]["attributes"]["dn"])
            intf_list[node] = node_intf_list
    return intf_list  # return a dictionary in {node, [interface list] format}
