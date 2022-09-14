from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import AdminUser

admin.site.register(AdminUser, UserAdmin)