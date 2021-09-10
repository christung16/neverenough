#!/usr/bin/env python

from flask import Flask, render_template, request, flash, redirect, url_for
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.inspection import inspect
from aci import list_intf
from hcl import hcl_overlay, hcl_underlay, hcl_policy, hcl_get_epgs, hcl_vm
import datetime, pytz
import time
import credential

# Init app
app = Flask(__name__)
dbUrl = credential.dbUrl
dbUser = credential.dbUser
dbPassword = credential.dbPassword
dbConnector = "mysql+pymysql://" + dbUser + ":" + dbPassword + "@" + dbUrl + "/ops"

# MariaDB connector
app.config["SQLALCHEMY_DATABASE_URI"] = dbConnector  # Localhost
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = True
app.config["SECRET_KEY"] = "dev"

# Init database connection
db = SQLAlchemy(app)
# time.sleep(30) # Wait for db to be created, docker only

# Data model

table_list = ["Change", "Underlay", "overlay", "policy", "vm"]


class Change(db.Model):  # Define a change record
    id = db.Column(db.Integer, primary_key=True)
    epg = db.Column(db.String(128))
    bd = db.Column(db.String(128))
    dom = db.Column(db.String(128))
    intf = db.Column(db.String(128))
    datetime = db.Column(db.DateTime())


class Underlay(db.Model):  # Define underaly change record
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(128))
    domain = db.Column(db.String(128))
    lldp_status = db.Column(db.String(128))
    cdp_status = db.Column(db.String(128))
    leaf_block = db.Column(db.String(128))
    port = db.Column(db.String(128))
    aaep_name = db.Column(db.String(128))
    leaf_profile = db.Column(db.String(128))
    datetime = db.Column(db.DateTime())


class Overlay(db.Model):  # Define overlay change record
    id = db.Column(db.Integer, primary_key=True)
    epg1 = db.Column(db.String(128))
    epg2 = db.Column(db.String(128))
    epg3 = db.Column(db.String(128))
    bd1 = db.Column(db.String(128))
    bd2 = db.Column(db.String(128))
    bd3 = db.Column(db.String(128))
    datetime = db.Column(db.DateTime())


class Policy(db.Model):  # Define policy change record
    id = db.Column(db.Integer, primary_key=True)
    contract1 = db.Column(db.String(128))
    contract2 = db.Column(db.String(128))
    consumer_epg1 = db.Column(db.String(128))
    provider_epg1 = db.Column(db.String(128))
    consumer_epg2 = db.Column(db.String(128))
    provider_epg2 = db.Column(db.String(128))
    datetime = db.Column(db.DateTime())


class VM(db.Model):  # Define policy change record
    id = db.Column(db.Integer, primary_key=True)
    web_vm = db.Column(db.String(128))
    web_epg = db.Column(db.String(128))
    app_vm = db.Column(db.String(128))
    app_epg = db.Column(db.String(128))
    db_vm = db.Column(db.String(128))
    db_epg = db.Column(db.String(128))
    datetime = db.Column(db.DateTime())


# Instantiate table if not exist

if db.engine.table_names():
    for table in db.engine.table_names():
        if table not in [table_list]:
            db.create_all()
            db.session.commit()
else:
    db.create_all()
    db.session.commit()

# define timezone
tz = pytz.timezone("Asia/Hong_Kong")

# Home page
@app.route("/")
def homepage():
    return render_template("index.html")


@app.route("/record_underlay")
def underlay_record():
    return render_template(
        "record_underlay.html",
        records=Underlay.query.order_by(-Underlay.id).limit(10).all(),
    )  # show 10 recent changes


@app.route("/record_overlay")
def overlay_record():
    return render_template(
        "record_overlay.html",
        records=Overlay.query.order_by(-Overlay.id).limit(10).all(),
    )  # show 10 recent changes


@app.route("/record_policy")
def policy_record():
    return render_template(
        "record_policy.html",
        records=Policy.query.order_by(-Policy.id).limit(10).all(),
    )  # show 10 recent changes


@app.route("/record_vm")
def vm_record():
    return render_template(
        "record_vm.html",
        records=VM.query.order_by(-VM.id).limit(10).all(),
    )  # show 10 recent changes


# Request form for Underlay
@app.route("/underlay", methods=["POST", "GET"])
def underlay():
    domain_list = ["phy", "vmm"]
    lldp_list = ["first_app_lldp_disable", "first_app_lldp_enable"]
    cdp_list = ["first_app_cdp_disable", "first_app_cdp_enable"]
    leaf_list = ["101", "102", "103", "104"]
    port_list = list(range(1, 49))
    if request.method == "POST":
        domain = request.form.get("domain")
        lldp_status = request.form.get("lldp")
        cdp_status = request.form.get("cdp")
        leaf_block = int(request.form.get("leaf_block"))
        port = request.form.get("port")
        now = datetime.datetime.now(tz=tz)
        name = (
            "leaf_access_port_"
            + str(leaf_block)
            + "_1_"
            + str(port)
            + "_"
            + domain
            + "domain"
        )
        aaep_name = "aaep_first_app_fpr_" + domain + "domain"
        leaf_profile = "leaf-" + str(leaf_block) + "-profile-fpr-" + domain + "domain"
        underlay = Underlay(
            domain=domain,
            lldp_status=lldp_status,
            cdp_status=cdp_status,
            leaf_block=leaf_block,
            port=port,
            name=name,
            aaep_name=aaep_name,
            leaf_profile=leaf_profile,
            datetime=now,
        )
        db.session.add(underlay)
        db.session.commit()
        json = hcl_underlay(
            name, lldp_status, cdp_status, aaep_name, leaf_profile, leaf_block, port
        )
        flash(
            "Item created:"
            + " name = "
            + name
            + ", lldp_status = "
            + lldp_status
            + ", cdp_status = "
            + cdp_status
            + ", aaep_name = "
            + aaep_name
            + ", leaf_profile = "
            + leaf_profile
            + ", port = "
            + port
        )
        return redirect(
            url_for("underlay", _external=True, _scheme="https")
        )  # return url https://... with HAproxy as SSL terminator
    return render_template(
        "underlay.html",
        domain_list=domain_list,
        lldp_list=lldp_list,
        cdp_list=cdp_list,
        leaf_list=leaf_list,
        port_list=port_list,
    )


@app.route("/overlay", methods=["POST", "GET"])
def overlay():
    bd_list = ["app_bd", "database_bd", "fpr_inside_bd", "fpr_outside_bd", "web_bd"]
    if request.method == "POST":
        epg1 = request.form.get("epg1")
        bd1 = request.form.get("bd1")
        epg2 = request.form.get("epg2")
        bd2 = request.form.get("bd2")
        epg3 = request.form.get("epg3")
        bd3 = request.form.get("bd3")
        now = datetime.datetime.now(tz=tz)
        overlay = Overlay(
            epg1=epg1,
            epg2=epg2,
            epg3=epg3,
            bd1=bd1,
            bd2=bd2,
            bd3=bd3,
            datetime=now,
        )
        db.session.add(overlay)
        db.session.commit()
        hcl_overlay(epg1, bd1, epg2, bd2, epg3, bd3)
        return redirect(url_for("overlay", _external=True, _scheme="https"))
    return render_template(
        "overlay.html",
        bd_list=bd_list,
    )


@app.route("/policy", methods=["POST", "GET"])
def policy():
    epg_list = hcl_get_epgs()
    if request.method == "POST":
        consumer_epg1 = request.form.get("consumer_epg1")
        provider_epg1 = request.form.get("provider_epg1")
        consumer_epg2 = request.form.get("consumer_epg2")
        provider_epg2 = request.form.get("provider_epg2")
        contract1 = "Con_web_epg_to_app_epg"
        contract2 = "Con_app_epg_to_database_epg"
        now = datetime.datetime.now(tz=tz)
        policy = Policy(
            consumer_epg1=consumer_epg1,
            provider_epg1=provider_epg1,
            consumer_epg2=consumer_epg2,
            provider_epg2=provider_epg2,
            contract1=contract1,
            contract2=contract2,
            datetime=now,
        )
        db.session.add(policy)
        db.session.commit()
        hcl_policy(consumer_epg1, provider_epg1, consumer_epg2, provider_epg2)
        return redirect(url_for("policy", _external=True, _scheme="https"))
    return render_template(
        "policy.html",
        epg_list=epg_list,
    )


@app.route("/vm", methods=["POST", "GET"])
def vm():
    epg_list = hcl_get_epgs()
    if request.method == "POST":
        web_vm = request.form.get("web_vm")
        app_vm = request.form.get("app_vm")
        db_vm = request.form.get("db_vm")
        web_epg = request.form.get("web_epg")
        app_epg = request.form.get("app_epg")
        db_epg = request.form.get("db_epg")
        now = datetime.datetime.now(tz=tz)
        vm = VM(
            web_vm=web_vm,
            web_epg=web_epg,
            app_vm=app_vm,
            app_epg=app_epg,
            db_vm=db_vm,
            db_epg=db_epg,
            datetime=now,
        )
        db.session.add(vm)
        db.session.commit()
        hcl_vm(web_vm, app_vm, db_vm, web_epg, app_epg, db_epg)
        return redirect(url_for("vm", _external=True, _scheme="https"))
    return render_template(
        "vm.html",
        epg_list=epg_list,
    )


if __name__ == "__main__":
    app.run(debug=True, port=8080, host="0.0.0.0")
