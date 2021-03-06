from .models import account
from rest_framework import serializers

class accountSerializer(serializers.HyperlinkedModelSerializer):
	class Meta:
		model=account
		fields=['address','role','displayName','additionalData']
