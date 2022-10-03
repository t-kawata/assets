const FLT_ACC = 1
const FLT_ACCMISSED = 2
const FLT_ACCFAILED = 3

/**
 * Utils
 */
const info = function (msg) { KSR.info(msg) }
const notice = function (msg) { KSR.notice(msg) }
const getPv = function (name) { return KSR.pv.get('$' + name) }
const setFlag = function (flg) { return KSR.setflag(flg) }
const slSendReply = function (code, reason) { return KSR.sl.sl_send_reply(code, reason) }
const tCheckTrans = function () { return KSR.tm.t_check_trans() }
const tPreCheckTrans = function () { return KSR.tmx.t_precheck_trans() }
const hasToTag = function () { return KSR.siputils.has_totag() }
const looseRoute = function () { return KSR.rr.loose_route() }
const isMyselfRuri = function () { return KSR.is_myself_ruri() }
const isMyselfFuri = function () { return KSR.is_myself_furi() }
const tRelay = function () { return KSR.tm.t_relay() }
const slReplyError = function () { return KSR.sl.sl_reply_error() }

/********************************
 * Branch Routes bgn
 ********************************/
const routeReqInit = function () {
  if (!KSR.maxfwd.process_maxfwd(10)) { slSendReply(483, 'Too Many Hops'); return false; }
  if (!KSR.sanity.sanity_check(1511, 7)) {
    const srcIp = getPv('si')
    const srcPort = getPv('sp')
    notice('Malformed SIP message from ' + srcIp + ':' + srcPort)
    return false
  }
  return true
}
const routeCancel = function () {
  if (!KSR.is_CANCEL()) return true
  if (tCheckTrans() > 0) return routeRelay()
  return true
}
const routeAck = function () {
  if (!KSR.is_ACK()) return true
  if (tPreCheckTrans() > 0) { tCheckTrans(); return false; }
  tCheckTrans()
  return true
}
const routeWithinDlg = function () {
  if (hasToTag() < 0) return true
  if (looseRoute() > 0) {
    if (KSR.is_BYE()) {
      setFlag(FLT_ACC)
      setFlag(FLT_ACCFAILED)
    }
    return routeRelay()
  }
  if (KSR.is_SUBSCRIBE() && isMyselfRuri()) {
    if (!routePresence()) return false
  }
  if (KSR.is_ACK()) {
    if (tCheckTrans() > 0) tRelay()
    return false
  }
  slSendReply(404, 'Not here')
  return false
}
const routePresence = function () {
  if (!KSR.is_PUBLISH() && KSR.is_SUBSCRIBE()) return true
  slSendReply(404, 'Not here')
  return false
}
const routeRelay = function () {
  if (tRelay() < 0) slReplyError()
  return false
}
/********************************
 * Branch Routes end
 ********************************/

/**
 * Request Entry Point
 */
function ksr_request_route() {
  if (!routeReqInit()) return
  if (!routeCancel()) return
  if (!routeAck()) return
  if (!routeWithinDlg()) return
}
