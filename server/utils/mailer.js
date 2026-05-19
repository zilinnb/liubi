const nodemailer = require('nodemailer')
const { MAIL_HOST, MAIL_PORT, MAIL_SECURE, MAIL_USER, MAIL_PASS, MAIL_FROM } = require('../config/env')

let transporter = null

function getTransporter() {
	if (transporter) return transporter
	if (!MAIL_HOST || !MAIL_USER || !MAIL_PASS) {
		console.warn('[Mailer] 邮件未配置: MAIL_HOST, MAIL_USER, MAIL_PASS 缺失')
		return null
	}
	transporter = nodemailer.createTransport({
		host: MAIL_HOST,
		port: MAIL_PORT,
		secure: MAIL_SECURE,
		auth: { user: MAIL_USER, pass: MAIL_PASS },
		name: 'liu.bi'
	})
	return transporter
}

async function sendVerifyCode(email, code, typeLabel) {
	const tp = getTransporter()
	if (!tp) {
		console.warn('[Mailer] 邮件服务未配置，验证码: ' + code + ' (邮箱: ' + email + ')')
		return true
	}
	const html = `
	<div style="max-width:480px;margin:0 auto;padding:32px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
		<div style="text-align:center;margin-bottom:24px;">
			<div style="width:56px;height:56px;border-radius:14px;background:linear-gradient(135deg,#ff2442,#ff5a6e);display:inline-flex;align-items:center;justify-content:center;margin-bottom:12px;">
				<span style="color:#fff;font-size:28px;font-weight:800;">留</span>
			</div>
			<h1 style="color:#ff2442;font-size:24px;margin:0;">留笔</h1>
			<p style="color:#999;font-size:14px;margin:4px 0 0;">标记我的生活</p>
		</div>
		<div style="background:#f9f9f9;border-radius:12px;padding:24px;text-align:center;">
			<p style="color:#333;font-size:16px;margin:0 0 16px;">您正在进行<strong>${typeLabel}</strong>操作</p>
			<div style="background:#fff;border-radius:8px;padding:16px;display:inline-block;">
				<span style="font-size:32px;font-weight:700;letter-spacing:8px;color:#ff2442;">${code}</span>
			</div>
			<p style="color:#999;font-size:13px;margin:16px 0 0;">验证码5分钟内有效，请勿泄露给他人</p>
		</div>
		<p style="color:#ccc;font-size:12px;text-align:center;margin-top:24px;">如非本人操作，请忽略此邮件</p>
		<p style="color:#ddd;font-size:11px;text-align:center;margin-top:12px;">此邮件由留笔系统自动发送，请勿回复</p>
	</div>`

	try {
		const fromName = MAIL_FROM || '留笔'
		const fromEmail = MAIL_USER
		const info = await tp.sendMail({
			from: `"${fromName}" <${fromEmail}>`,
			to: email,
			subject: `【留笔】${typeLabel}验证码`,
			html
		})
		console.log('[Mailer] 验证码已发送:', email, info.messageId || '')
		return true
	} catch (e) {
		console.error('[Mailer] 发送失败:', e.message)
		throw new Error('邮件发送失败，请检查邮箱配置')
	}
}

async function sendNotificationEmail(toEmail, fromUserName, notifType, targetTitle, content) {
	const tp = getTransporter()
	if (!tp) {
		console.warn('[Mailer] 邮件服务未配置，跳过通知邮件')
		return
	}
	const typeLabels = { 1: '赞', 2: '评论', 3: '关注', 6: '收藏' }
	const typeLabel = typeLabels[notifType] || '互动'
	const actionTexts = { 1: '赞了你的动态', 2: '评论了你的动态', 3: '关注了你', 6: '收藏了你的动态' }
	const actionText = actionTexts[notifType] || '与你互动'
	const html = `
<div style="max-width:480px;margin:0 auto;padding:32px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
	<div style="text-align:center;margin-bottom:24px;">
		<div style="width:56px;height:56px;border-radius:14px;background:linear-gradient(135deg,#ff2442,#ff5a6e);display:inline-flex;align-items:center;justify-content:center;margin-bottom:12px;">
			<span style="color:#fff;font-size:28px;font-weight:800;">留</span>
		</div>
		<h1 style="color:#ff2442;font-size:24px;margin:0;">留笔</h1>
		<p style="color:#999;font-size:14px;margin:4px 0 0;">标记我的生活</p>
	</div>
	<div style="background:#f9f9f9;border-radius:12px;padding:24px;">
		<p style="color:#333;font-size:16px;margin:0 0 12px;"><strong style="color:#ff2442;">${fromUserName}</strong> ${actionText}</p>
		${targetTitle ? `<div style="background:#fff;border-radius:8px;padding:12px 16px;margin-bottom:12px;border-left:3px solid #ff2442;"><span style="color:#555;font-size:14px;">${targetTitle}</span></div>` : ''}
		${content ? `<div style="background:#fff;border-radius:8px;padding:12px 16px;"><span style="color:#666;font-size:14px;">${content}</span></div>` : ''}
	</div>
	<p style="color:#ccc;font-size:12px;text-align:center;margin-top:24px;">此邮件由留笔系统自动发送，请勿回复</p>
</div>`

	try {
		const fromName = MAIL_FROM || '留笔'
		const fromEmail = MAIL_USER
		const info = await tp.sendMail({
			from: `"${fromName}" <${fromEmail}>`,
			to: toEmail,
			subject: `【留笔】${fromUserName}${actionText}`,
			html
		})
		console.log('[Mailer] 通知邮件已发送:', toEmail, info.messageId || '')
	} catch (e) {
		console.error('[Mailer] 通知邮件发送失败:', e.message)
	}
}

module.exports = { sendVerifyCode, sendNotificationEmail }
