/**
 * Consts
 */
const FLT_ACC = 1
const FLT_ACCMISSED = 2
const FLT_ACCFAILED = 3
const MAX_CONTACTS = 5
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
const setToHtable = function (table, key, value) {
  var rtn = 0
  switch (typeof value) {
    case 'number': rtn = KSR.htable.sht_seti(table, key, value); break;
    case 'string': rtn = KSR.htable.sht_sets(table, key, value); break;
    default: rtn = KSR.htable.sht_sets(table, key, JSON.stringify(value)); break;
  }
  return rtn
}
const setFlag = function (flg) { return KSR.setflag(flg) }
const setToRegmap = function (key, value) {
  info('Set a regmap record(' + key + ': ' + value + ')')
  return setToHtable('regmap', key, value)
}
const setUacReq = function (key, value) {
  return setPv('uac_req(' + key + ')', value)
}
const getPv = function (name) { return KSR.pv.get('$' + name) }
const getFromHtable = function (table, key) { return KSR.htable.sht_get(table, key) }
const getFromRegmap = function (key) {
  info('Get a regmap record by key(' + key + ')')
  return getFromHtable('regmap', key)
}
const delFromHtable = function (table, key) { return KSR.htable.sht_rm(table, key) }
const delFromRegmap = function (key) {
  info('Delete a regmap record by key(' + key + ')')
  return delFromHtable('regmap', key)
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
const sendRegister = function () {
  return sendUacReq('REGISTER', {
    ruri: 'sip:10.1.10.4:5061',
    furi: 'sip:101@44.225.154.71:5061',
    turi: 'sip:101@44.225.154.71:5061'
  }, {
    Contact: '<sip:101@10.1.10.140:5061>',
    Expires: 60,
    Allow: 'INVITE, ACK, CANCEL, BYE, NOTIFY, REFER, MESSAGE, OPTIONS, INFO, SUBSCRIBE',
    'Allow-Events': 'presence, kpml, talk'
  }, '')
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
const isValidUsername = function (username) { return !!(/^s[0-9]{11}$/.exec(username)) }
const isValidRegisteringContact = function (contact) { return isValidUsername(getUsernameFromContact(contact)) }
const isFullContactsNow = function (contactsCount) { return contactsCount >= MAX_CONTACTS }
const isTheTimingToDeleteFromRegmap = function (contacts, sipFullUrl, isContactExpired) {
  if (isContactExpired) { return !contacts || (contacts && contacts.length === 0) }
  return  contacts &&
          contacts.length === 1 &&
          contacts.filter(function (c) { return c.Address === sipFullUrl }).length === 1
}
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
const removeNotFreshOneContactWhenOverMaxContact = function (username) {
  const contacts = getContactsByAor(username)
  const addressOfRemovingTargetContact = getRemovingTargetContact(username, contacts).Address
  if (isUndefined(addressOfRemovingTargetContact)) return contacts
  info('Try to delete contact(' + addressOfRemovingTargetContact + ')')
  if (unregister('location', addressOfRemovingTargetContact) > 0) {
    info('Succeeded to unregister a contact(' + addressOfRemovingTargetContact + ')')
  } else {
    info('Failed to unregister a contact(' + addressOfRemovingTargetContact + ')')
  }
  const dstUriFromRegmapForRemoving = getFromRegmap(username)
  if (isNull(dstUriFromRegmapForRemoving)) return contacts
  // TODO 5. request UNREGISTER to this dstUri
  return contacts
}
const getCorrectDstUriWithSettingRegmapRecord = function (username, contact, contacts) {
  const dstUriFromRegmap = getDstUriFromRegMap(username)
  var dstUri = ''
  if (!isNull(dstUriFromRegmap)) {
    info('A saved Dst-URI(' + dstUriFromRegmap + ') was found in regmap for an AOR(' + username + ').')
    info('Use [' + dstUriFromRegmap + '] as Dst-URI to dispatch now.')
    dstUri = dstUriFromRegmap
  } else {
    info('No saved Dst-URI was found in regmap for an AOR(' + username + ').')
    info('Select a Dst-URI with auto-select-system of dispatcher.')
    if (!routeSelectDst()) return false
    dstUri = getPv('du')
    info('Use [' + dstUri + '] as Dst-URI to dispatch now.')
    setToRegmap(username, dstUri)
  }
  return dstUri
}
const getDstUriToRegister = function (contact) {
  const username = getUsernameFromContact(contact)
  if (!username) { info('Failed to get username from contact.'); return false; }
  const contacts = removeNotFreshOneContactWhenOverMaxContact(username)
  const dstUri = getCorrectDstUriWithSettingRegmapRecord(username, contact, contacts)
  if (!dstUri) { info('Failed to get any Dst-URI to dispatch.'); return false; }
  info('Now we decided to use [' + dstUri + '] as Dst-URI to dispatch.')
  return dstUri
}
const getDstUriToUnRegister = function (contact) {
  const username = getUsernameFromContact(contact)
  if (!username) { info('Failed to get username from contact.'); return false; }
  const dstUri = getDstUriFromRegMap(username)
  if (!dstUri) { info('Failed to get any Dst-URI to send Un-REGISTER.'); return false; }
  info('Now we decided to use [' + dstUri + '] as Dst-URI to send Un-REGISTER.')
  return { dstUri, username }
}
const tryToCleanRegmap = function (username, contact, isContactExpired) {
  const contacts = getContactsByAor(username)
  const sipFullUrl = getSipFullUrlFromContact(contact)
  if (isTheTimingToDeleteFromRegmap(contacts, sipFullUrl, isContactExpired)) delFromRegmap(username)
}
const saveToRegister = function (contact) {
  // TODO 10. saveしてdispatch先（dstUri）へrequest
  sendRegister()

  info('Try to register a contact: ' + contact)
  if (saveWithoutReply('location') < 0) slReplyError()
  regSendReply()
  info('Registered a contact: ' + contact)
}
const saveToUnRegister = function (contact) {
  info('Try to unregister a contact: ' + contact)
  if (saveWithReply('location') < 0) slReplyError()
  info('Unregistered a contact: ' + contact)
}
const getDstUriFromRegMap = function (username) {
  info('Try to search a saved Dst-URI in regmap for an AOR(' + username + ')')
  return getFromRegmap(username)
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
  if (KSR.is_REGISTER() || isMyselfFuri()) {
    const fhost = KSR.kx.gete_fhost()
    if (KSR.auth_db.auth_check(fhost, "subscriber", 1) < 0) { KSR.auth.auth_challenge(fhost, 0); return false; }
    if (!KSR.is_method_in("RP")) KSR.auth.consume_credentials()
  }
  if (!isMyselfFuri() && !isMyselfRuri()) { slSendReply(403, 'Not relaying'); return false; }
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
  if (!contact || !isValidRegisteringContact(contact)) { reply404(); return false; }
  if (!contact.match(/expires=0/)) return routeRegister(contact)
  else return routeUnregister(contact)
}
const routeRegister = function (contact) {
  info('Got REGISTER req with contact(' + contact + ')')
  const dstUri = getDstUriToRegister(contact)
  if (!dstUri) { reply404(); return false; }
  saveToRegister(contact)
  return false
}
const routeUnregister = function (contact) {
  info('Got Un-REGISTER req with contact(' + contact + ')')
  const data = getDstUriToUnRegister(contact)
  if (data.dstUri) {
    // TODO UNREGISTER 2. dstUriにUn-REGISTERのrequest
    tryToCleanRegmap(data.username, contact, false)
  }
  saveToUnRegister(contact)
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
  switch (eventName) {
    case 'usrloc:contact-expired': onContactExpired(); break;
    default: break;
  }
}
const onContactExpired = function () {
  const contactAddr = getPv('ulc(exp=>addr)')
  const contact = '<' + contactAddr + '>'
  info('A contact(' + contact + ') was expired.')
  const data = getDstUriToUnRegister(contact)
  if (data.dstUri) {
    // TODO UNREGISTER 2. dstUriにUn-REGISTERのrequest
    tryToCleanRegmap(data.username, contact, true)
  }
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
