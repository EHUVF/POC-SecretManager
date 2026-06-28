FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-windowsservercore-ltsc2019

WORKDIR C:/inetpub/wwwroot

COPY bin/ ./bin/
COPY Web.config ./
COPY Global.asax ./

EXPOSE 80
