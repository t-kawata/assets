/**
 * Consts
 */
const FLT_ACC = 1
const FLT_ACCMISSED = 2
const FLT_ACCFAILED = 3
const FLB_NATB = 6
const FLB_NATSIPPING = 7
const MAX_CONTACTS = 5
const AUTH_COMMON_DOMAIN = 'shyme'
const DEFAULT_STICKY_EXPIRE = 86400 // 24h
const STICKY_STATUS_KEY = 'STICKY_STATUS'
const USERNAME_FORMAT = /^s[0-9]{11}$/

const JSDT_DEBUG = true

/**
 * Utils
 */
const info = function (msg) { if (JSDT_DEBUG) KSR.info(msg) }
const notice = function (msg) { KSR.notice(msg) }
const error = function (msg) { KSR.err(msg) }
const setPv = function (key, value) {
  var rtn = 0
  const lastKey = '$' + key
  switch (typeof value) {
    case 'number': rtn = KSR.pv.seti(lastKey, value); break;
    case 'string': rtn = KSR.pv.sets(lastKey, value); break;
    default: rtn = KSR.pv.sets(lastKey, JSON.stringify(value)); break;
  }
  return rtn
}
const setToHtable = function (table, key, value, expire) {
  var rtn = 0
  switch (typeof value) {
    case 'number': rtn = KSR.htable.sht_setxi(table, key, value, expire); break;
    case 'string': rtn = KSR.htable.sht_setxs(table, key, value, expire); break;
    default: rtn = KSR.htable.sht_setxs(table, key, JSON.stringify(value), expire); break;
  }
  return rtn
}
const setFlag = function (flg) { return KSR.setflag(flg) }
const setToSticky = function (key, value, expire) {
  const expireNum = Number(expire)
  const expireSeconds = expireNum > 0 ? expireNum : DEFAULT_STICKY_EXPIRE
  info('Set a sticky record(' + key + ': ' + value + '; expire=' + expireSeconds + ')')
  return setToHtable('sticky', key, value, expireSeconds)
}
const setUacReq = function (key, value) {
  return setPv('uac_req(' + key + ')', value)
}
const getPv = function (name) { return KSR.pv.get('$' + name) }
const getFromHtable = function (table, key) { return KSR.htable.sht_get(table, key) }
const getFromSticky = function (key) {
  info('Get a sticky record by key(' + key + ')')
  return getFromHtable('sticky', key)
}
const getStickyStatus = function () {
  const status = getFromHtable('settings', STICKY_STATUS_KEY)
  return status ? Number(status) : 0
}
const delFromHtable = function (table, key) { return KSR.htable.sht_rm(table, key) }
const delFromSticky = function (key) {
  info('Delete a sticky record by key(' + key + ')')
  return delFromHtable('sticky', key)
}
const sendUacReq = function (method, params, hdrs, body) {
  if (!method) return 0
  const lastBody = body || ''
  const defaultHeaders = { 'Content-Length': lastBody.length }
  const hdrsObj = hdrs && typeof hdrs === 'object' ? Object.assign(defaultHeaders, hdrs) : defaultHeaders
  const hdrsArr = Object.keys(hdrsObj).map(function (k) { return k + ': ' + hdrsObj[k] })
  setUacReq('hdrs', hdrsArr.join("\n"))
  setUacReq('method', method)
  setUacReq('body', lastBody)
  if (params && typeof params === 'object') { Object.keys(params).forEach(function (k) { setUacReq(k, params[k]) }) }
  return KSR.uac.uac_req_send()
}
const slSendReply = function (code, reason) { return KSR.sl.sl_send_reply(code, reason) }
const sendReply = function (code, reason) { return KSR.sl.send_reply(code, reason) }
const reply404 = function () { return slSendReply(404, 'Not found') }
const tCheckTrans = function () { return KSR.tm.t_check_trans() }
const tPreCheckTrans = function () { return KSR.tmx.t_precheck_trans() }
const hasToTag = function () { return KSR.siputils.has_totag() }
const looseRoute = function () { return KSR.rr.loose_route() }
const isMyselfRuri = function () { return KSR.is_myself_ruri() }
const isMyselfFuri = function () { return KSR.is_myself_furi() }
const removeHf = function (headerName) { return KSR.textops.remove_hf(headerName) }
const recordRoute = function () { return KSR.rr.record_route() }
const save = function (table, flags) { return KSR.registrar.save(table, flags) }
const saveWithReply = function () { return save('location') }
const saveWithoutReply = function () { return save('location', 2) }
const regSendReply = function () { return KSR.registrar.reg_send_reply() }
const unregister = function (table, uri) { return KSR.registrar.unregister(table, uri) }
const dsSelectDst = function (set, alg) { return KSR.dispatcher.ds_select_dst(set, alg) }
const dsNextDst = function () { return KSR.dispatcher.ds_next_dst() }
const tRelay = function () { return KSR.tm.t_relay() }
const slReplyError = function () { return KSR.sl.sl_reply_error() }
const tOnFailure = function (failureMethodName) { return KSR.tm.t_on_failure(failureMethodName) }
const tIsCanceled = function () { return KSR.tm.t_is_canceled() }
const tCheckStatus = function (replyCode) { return KSR.tm.t_check_status(replyCode) }
const tBranchTimeout = function () { return KSR.tm.t_branch_timeout() }
const tBranchReplied = function () { return KSR.tm.t_branch_replied() }
const isNull = function (data) { return data === null }
const isUndefined = function (data) { return data === undefined }
const isValidUsername = function (username) { return !!(USERNAME_FORMAT.exec(username)) }
const isValidUsernameContact = function (contact) { return isValidUsername(getUsernameFromContact(contact)) }
const isFullContactsNow = function (contactsCount) { return contactsCount >= MAX_CONTACTS }
const execRPC = function (method, paramsArr) {
  const rtn = KSR.jsonrpcs.exec(JSON.stringify({ jsonrpc: '2.0', method, params: paramsArr }))
  if (rtn < 0) return null
  const code = getPv('jsonrpl(code)')
  const body = getPv('jsonrpl(body)')
  if (code !== 200) {
    info('RPC Code: ' + code)
    info('RPC Body: ' + JSON.stringify(JSON.parse(body)))
    info('RPC Failed Method: ' + method)
    info('RPC Failed Method Params: ' + JSON.stringify(paramsArr))
    return null;
  }
  return JSON.parse(body)
}
const getSipBaseUrlFromStr = function (str) { return String(str).match(/sip:.+@.+?:.[0-9]+/) || '' }
const getSipFullUrlFromContact = function (contact) {
  const tmp = String(contact).match(/\<.+?\>/) || []
  return tmp.length > 0 ? tmp[0].replace(/\<|\>/g, '') : ''
}
const getUsernameFromContact = function (contact) {
  if (!contact) return ''
  const ex1 = contact.split('@')
  if (ex1.length < 2) return ''
  const ex2 = ex1[0].split(':')
  if (ex2.length < 2) return ''
  return ex2[1]
}
const getContactsByAor = function (aorName) {
  const rpcResult = execRPC('ul.lookup', ['location', aorName + '@'])
  if (isNull(rpcResult)) return null
  const contacts = rpcResult.result.Contacts
  if (contacts.length === 0) return []
  const rtn = []
  contacts.forEach(function (c) { rtn.push(c.Contact) })
  return rtn
}
const getRemovingTargetContact = function (username, contacts) {
  if (isNull(contacts)) { info('No contacts for a AOR(' + username + ')'); return {}; }
  const length = contacts.length
  info(length + ' contacts were found for AOR('+ username + ') in this proxy now.')
  if (length === 0 || !isFullContactsNow(length)) return {}
  info('This REGISTER req is over MAX_CONTACTS(' + MAX_CONTACTS + ')')
  var minLastModifiedTimeStamp = 0
  var removingTargetContact = {}
  contacts.forEach(function (c) {
    if (minLastModifiedTimeStamp !== 0 && c['Last-Modified'] >= minLastModifiedTimeStamp) return
    minLastModifiedTimeStamp = c['Last-Modified']
    removingTargetContact = c
  })
  return removingTargetContact
}
const removeNotFreshOneContactWhenOverMaxContact = function (contact) {
  const username = getUsernameFromContact(contact)
  if (!username) { info('Failed to get username from contact.'); return false; }
  const contacts = getContactsByAor(username)
  const addressOfRemovingTargetContact = getRemovingTargetContact(username, contacts).Address
  if (isUndefined(addressOfRemovingTargetContact)) return
  info('Try to delete contact(' + addressOfRemovingTargetContact + ')')
  if (unregister('location', addressOfRemovingTargetContact) > 0) {
    info('Succeeded to unregister a contact(' + addressOfRemovingTargetContact + ')')
  } else {
    info('Failed to unregister a contact(' + addressOfRemovingTargetContact + ')')
  }
}
const _selectDst = function () {
  info('Select a Dst-URI with auto-select-system of dispatcher.')
  if (dsSelectDst(1, 4) < 0) { sendReply(404, 'No destination'); return ''; }
  dstUri = getPv('du')
  info('Use [' + dstUri + '] as Dst-URI to dispatch now.')
  return dstUri
}
const selectDstUri = function (username, isStickyByAor, expire) {
  if (!username || !isStickyByAor) return _selectDst()
  else {
    const dstUriFromSticky = getDstUriFromSticky(username)
    var dstUri = ''
    if (!isNull(dstUriFromSticky)) {
      info('A saved Dst-URI(' + dstUriFromSticky + ') was found in sticky for an AOR(' + username + ').')
      info('Use [' + dstUriFromSticky + '] as Dst-URI to dispatch now.')
      dstUri = dstUriFromSticky
      setPv('du', dstUri)
    } else {
      info('No saved Dst-URI was found in sticky for an AOR(' + username + ').')
      dstUri = _selectDst()
      if (dstUri) setToSticky(username, dstUri, expire)
    }
    return dstUri
  }
}
const saveToRegister = function (contact) {
  info('Try to register a contact: ' + contact)
  if (saveWithReply('location') < 0) slReplyError()
  info('Registered a contact: ' + contact)
}
const saveToUnRegister = function (contact) {
  info('Try to unregister a contact: ' + contact)
  if (saveWithReply('location') < 0) slReplyError()
  info('Unregistered a contact: ' + contact)
}
const getDstUriFromSticky = function (username) {
  info('Try to search a saved Dst-URI in sticky for an AOR(' + username + ')')
  return getFromSticky(username)
}

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
  if (KSR.is_KDMQ()) { KSR.dmq.handle_message(); return false; }
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
  reply404()
  return false
}
const routeAuth = function () {
  if (KSR.is_REGISTER()) {
    const contact = getPv('ct')
    if (!contact || !isValidUsernameContact(contact)) {
      info('Invalid format username contact!! (' + contact + ')')
      reply404();
      return false;
    }
    if (KSR.auth_db.auth_check(AUTH_COMMON_DOMAIN, "subscriber", 1) < 0) {
      KSR.auth.auth_challenge(AUTH_COMMON_DOMAIN, 0)
      return false
    }
    if (!KSR.is_method_in("RP")) KSR.auth.consume_credentials()
  }
  return true
}
const routeInvite = function () {
  if (KSR.is_INVITE()) setFlag(FLT_ACC)
  return true
}
const routePresence = function () {
  if (!KSR.is_PUBLISH() && !KSR.is_SUBSCRIBE()) return true
  reply404()
  return false
}
const routeRegisterEntry = function () {
  if (!KSR.is_REGISTER()) return true
  const contact = getPv('ct')
  if (!contact.match(/expires=0/)) return routeRegister(contact)
  else return routeUnregister(contact)
}
const routeRegister = function (contact) {
  info('Got REGISTER req with contact(' + contact + ')')
  removeNotFreshOneContactWhenOverMaxContact(contact)
  saveToRegister(contact)
  return false
}
const routeUnregister = function (contact) {
  info('Got Un-REGISTER req with contact(' + contact + ')')
  saveToUnRegister(contact)
  return false
}
const routeDispatch = function () {
  const username = getUsernameFromContact(getPv('ct'))
  if (!username || !isValidUsername(username)) { reply404(); return false; }
  const isStickyByAor = getStickyStatus() > 0
  if (!selectDstUri(username, isStickyByAor)) return false
  if (!isStickyByAor) tOnFailure('failureRouteRtfDispatch')
  return routeRelay()
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
  switch (eventName) {
    case 'usrloc:contact-expired': onContactExpired(); break;
    default: break;
  }
}
const onContactExpired = function () {
  const contactAddr = getPv('ulc(exp=>addr)')
  const contact = '<' + contactAddr + '>'
  info('A contact(' + contact + ') was expired.')
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

  if (!routeAuth()) return

  removeHf('Route')
  if (KSR.is_INVITE() || KSR.is_SUBSCRIBE()) recordRoute()

  if (!routeInvite()) return
  if (!routePresence()) return
  if (!routeRegisterEntry()) return

  const usernameInReqURI = getPv('rU')
  if (isNull(usernameInReqURI)) { slSendReply(484, 'Address Incomplete'); return; }

  if (!routeDispatch()) return
}
