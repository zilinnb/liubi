require('dotenv').config()

module.exports = {
	PORT: process.env.PORT || 3000,
	JWT_SECRET: process.env.JWT_SECRET || 'liubi_secret',
	ADMIN_USER: process.env.ADMIN_USER || 'admin',
	ADMIN_PASS: process.env.ADMIN_PASS || 'admin123',
	MAIL_HOST: process.env.MAIL_HOST || '',
	MAIL_PORT: Number(process.env.MAIL_PORT) || 465,
	MAIL_SECURE: process.env.MAIL_SECURE === 'true' || process.env.MAIL_PORT === '465',
	MAIL_USER: process.env.MAIL_USER || '',
	MAIL_PASS: process.env.MAIL_PASS || '',
	MAIL_FROM: process.env.MAIL_FROM || '留笔'
}
