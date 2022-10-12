/**
 * Consts
 */
const FLT_ACC = 1
const FLT_ACCMISSED = 2
const FLT_ACCFAILED = 3
const JSDT_DEBUG = true

/**
 * Utils
 */
const info = function (msg) { if (JSDT_DEBUG) KSR.info(msg) }
const notice = function (msg) { KSR.notice(msg) }
const getPv = function (name) { return KSR.pv.get('$' + name) }
const setFlag = function (flg) { return KSR.setflag(flg) }
const slSendReply = function (code, reason) { return KSR.sl.sl_send_reply(code, reason) }
const sendReply = function (code, reason) { return KSR.sl.send_reply(code, reason) }
const tCheckTrans = function () { return KSR.tm.t_check_trans() }
const tPreCheckTrans = function () { return KSR.tmx.t_precheck_trans() }
const hasToTag = function () { return KSR.siputils.has_totag() }
const looseRoute = function () { return KSR.rr.loose_route() }
const isMyselfRuri = function () { return KSR.is_myself_ruri() }
const isMyselfFuri = function () { return KSR.is_myself_furi() }
const removeHf = function (headerName) { return KSR.textops.remove_hf(headerName) }
const recordRoute = function () { return KSR.rr.record_route() }
const save = function (table, flags) { return KSR.registrar.save(table, flags) }
const dsSelectDst = function (set, alg) { return KSR.dispatcher.ds_select_dst(set, alg) }
const dsNextDst = function () { return KSR.dispatcher.ds_next_dst() }
const tRelay = function () { return KSR.tm.t_relay() }
const slReplyError = function () { return KSR.sl.sl_reply_error() }
const tOnFailure = function (failureMethodName) { return KSR.tm.t_on_failure(failureMethodName) }
const tIsCanceled = function () { return KSR.tm.t_is_canceled() }
const tCheckStatus = function (replyCode) { return KSR.tm.t_check_status(replyCode) }
const tBranchTimeout = function () { return KSR.tm.t_branch_timeout() }
const tBranchReplied = function () { return KSR.tm.t_branch_replied() }

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
const routeKDMQ = function () {
  if (KSR.is_KDMQ()) {
    KSR.dmq.handle_message()
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
const routeInvite = function () {
  if (KSR.is_INVITE()) setFlag(FLT_ACC)
  return true
}
const routePresence = function () {
  if (!KSR.is_PUBLISH() && !KSR.is_SUBSCRIBE()) return true
  slSendReply(404, 'Not here')
  return false
}
const routeRegisterEntry = function () {
  if (!KSR.is_REGISTER()) return true
  const contact = getPv('ct')
  if (!contact) return false
  if (!contact.match(/expires=0/)) return routeRegister(contact)
  else return routeUnregister(contact)
  // if (!routeSelectDst()) return false
  // const reqUri = getPv('ru')
  // const dstUri = getPv('du')
  // info('Request-URI: ' + reqUri)
  // info('Destination-URI: ' + dstUri)
  // return false
}
const routeRegister = function (contact) {
  info('Try to register a contact: ' + contact)
  if (save('location') < 0) slReplyError()
  info('Registered a contact: ' + contact)

  return false
}
const routeUnregister = function (contact) {
  info('Try to unregister a contact: ' + contact)
  if (save('location') < 0) slReplyError()
  info('Unregistered a contact: ' + contact)

  return false
}
const routeDispatch = function () {
  if (!routeSelectDst()) return false
  tOnFailure('failureRouteRtfDispatch')
  return routeRelay()
}
const routeSelectDst = function () {
  if (dsSelectDst(1, 4) < 0) { sendReply(404, 'No destination'); return false; }
  return true
}
const routeRelay = function () {
  if (tRelay() < 0) slReplyError()
  return false
}
const failureRouteRtfDispatch = function () {
  if (tIsCanceled() > 0) return
  if (tCheckStatus('500') || (tBranchTimeout() > 0 && !(tBranchReplied() > 0))) {
    if (dsNextDst() > 0) {
      tOnFailure('failureRouteRtfDispatch')
      return routeRelay()
    }
  }
}
/********************************
 * Branch Routes end
 ********************************/

/********************************
 * Event Handlers bgn
 ********************************/
const onRegistrarEvent = function (eventName) {
  info('Event Name: ' + eventName)
  info(KSR.pv.getw('$ulc(exp=>addr)'))
}
/********************************
 * Event Handlers end
 ********************************/

/**
 * Request Entry Point
 */
const ksr_request_route = function () {
  if (!routeReqInit()) return
  if (!routeKDMQ()) return
  if (!routeCancel()) return
  if (!routeAck()) return
  if (!routeWithinDlg()) return

  removeHf('Route')
  if (KSR.is_INVITE() || KSR.is_SUBSCRIBE()) recordRoute()

  if (!routeInvite()) return
  if (!routePresence()) return
  if (!routeRegisterEntry()) return

  const usernameInReqURI = getPv('rU')
  if (usernameInReqURI === null) { slSendReply(484, 'Address Incomplete'); return; }

  if (!routeDispatch()) return
}
