module("luci.controller.glinet_sms_webapp", package.seeall)

function index()
    if not nixio.fs.access("/www/sms/index.html") then
        return
    end
    entry({"admin", "services", "glinet_sms_webapp"}, call("redirect_to_app"), _("GL.iNet SMS Tool"), 90).dependent = false
end

function redirect_to_app()
    luci.http.redirect("/sms/")
end
