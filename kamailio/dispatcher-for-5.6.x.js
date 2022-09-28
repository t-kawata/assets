const FLT_ACC = 1
const FLT_ACCMISSED = 2
const FLT_ACCFAILED = 3

/**
 * Utils
 */
const info = function (msg) { KSR.info(msg) }
const notice = function (msg) { KSR.notice(msg) }
const getPv = function (name) { return KSR.pv.get('$' + name) }
const slSendReply = function (code, reason) { return KSR.sl.sl_send_reply(code, reason) }
const tCheckTrans = function () { return KSR.tm.t_check_trans() }
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
const routeRelay = function () {
  if (KSR.tm.t_relay() < 0) slReplyError()
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
}
