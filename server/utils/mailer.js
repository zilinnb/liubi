const nodemailer = require('nodemailer')

// 从数据库获取邮箱配置并发送邮件
async function sendMail(db, to, subject, html) {
	// 从数据库读取配置
	const [rows] = await db.query("SELECT `key`, `value` FROM email_config")
	const config = {}
	rows.forEach(r => { config[r.key] = r.value })

	if (!config.smtp_host || !config.smtp_user || !config.smtp_pass) {
		throw new Error('邮箱未配置，请在管理后台设置')
	}

	const transporter = nodemailer.createTransport({
		host: config.smtp_host,
		port: parseInt(config.smtp_port) || 465,
		secure: config.smtp_secure !== 'false',
		auth: {
			user: config.smtp_user,
			pass: config.smtp_pass
		}
	})

	const from = config.smtp_from_name ? `"${config.smtp_from_name}" <${config.smtp_user}>` : config.smtp_user

	await transporter.sendMail({
		from,
		to,
		subject,
		html
	})
}

// 发送验证码邮件
async function sendVerifyCode(db, email, code, typeLabel) {
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

	await sendMail(db, email, `【留笔】${typeLabel}验证码`, html)
}

// 发送通知邮件
async function sendNotificationEmail(db, toEmail, fromUserName, notifType, targetTitle, content) {
	const typeLabels = { 1: '赞', 2: '评论', 3: '关注', 6: '收藏' }
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
		await sendMail(db, toEmail, `【留笔】${fromUserName}${actionText}`, html)
	} catch (e) {
		console.error('[Mailer] 通知邮件发送失败:', e.message)
	}
}

module.exports = { sendMail, sendVerifyCode, sendNotificationEmail }
