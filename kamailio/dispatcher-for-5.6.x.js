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

/**
 * Branch Routes
 */
const ksrRouteReqInit = function () {
  if (!KSR.maxfwd.process_maxfwd(10)) { slSendReply(483, 'Too Many Hops'); return false; }
  const srcIp = getPv('si')
  const srcPort = getPv('sp')
  info('srcIp: ' + srcIp)
  info('srcPort: ' + srcPort)
  if (!KSR.sanity.sanity_check(1511, 7)) { notice('Malformed SIP message from ' + srcIp + ':' + srcPort); return false }
  return true
}

/**
 * Request Entry Point
 */
function ksr_request_route() {
  if (!ksrRouteReqInit()) return
}
