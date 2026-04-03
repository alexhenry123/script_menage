# -------------------------------------- Assignation de variables --------------------------------------



# Choix d'encodage
$PSDefaultParameterValues["*:Encoding"] = "UTF8"

# Choisir ce que fait le script s'il y a une erreur
$ErrorActionPreference = "Stop"

# True : tester et voir quelles actions prendront le script
# False : exécuter les commandes du script 
$WhatIfPreference = $false



# -------------------------------------------- Fonctions --------------------------------------------



# Fonction pour journaliser les actions du script dans le fichier log
function Write-Log 
{
    param(
        [Parameter(Mandatory)]
        [string] $Contenu,

        [Parameter(Mandatory)]
        [ValidateSet("INFO", "AVERTISSEMENT", "ERREUR")]
        [string] $Sévérité
    )

    # Assignation des variables
    $chemin_logs = "C:\Scripts\Logs\journaux.log"
    $horodatage = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Mettre le contenu des actions du script dans le fichier de journaux avec l'horodatage et la sévérité 
    Set-Content -Path $chemin_logs -Value "$($horodatage)   -   $($Sévérité)   -   $($Contenu)"
}

# Fonction 1 : Suppression des utilisateurs désuets
function Remove-Users 
{
    # SID des comptes systèmes et loaner qui ne doivent pas être supprimés
    $SID_loaner = "S-1-12-1-3684075938-1177419516-3185746318-4102645725"
    $SID_profil_systeme = "S-1-5-18"
    $SID_service_local = "S-1-5-19"
    $SID_service_reseau = "S-1-5-20"

    Write-Host "Suppression des utilisateurs en cours..." -ForegroundColor Cyan

    # Supprimer tous les utilisateurs qui sont ni système ni loaner
    Remove-CimInstance -Query "SELECT * FROM Win32_UserProfile 
    WHERE SID != '$($SID_loaner)' 
    AND SID != '$($SID_service_local)' 
    AND SID != '$($SID_service_reseau)' 
    AND SID != '$($SID_profil_systeme)'" -WhatIf

    Write-Host "Les utilisateurs ont été supprimés avec succès" -ForegroundColor Green
    Write-Log -Sévérité "INFO" -Contenu "Les utilisateurs ont été supprimés avec succès"

    # Journalisation : utilisation du paramètre WhatIf pour journaliser les utilisateurs supprimés (Remove-CimInstance ne donne rien en output)
    $log_utilisateurs = Remove-CimInstance -Query "SELECT * FROM Win32_UserProfile WHERE SID != '$($SID_loaner)' AND SID != '$($SID_service_local)' AND SID != '$($SID_service_reseau)' AND SID != '$($SID_profil_systeme)'" -WhatIf 4>&1
    $log_utilisateurs | Write-Log -Sévérité "INFO" -Contenu $_
}

# Fonction 2 : Automatisation des mises à jour Windows et redémarrage automatique 
function Get-Update 
{
    # Prérequis : installer le module PSWindowsUpdate pour mettre à jour le système (s'il n'est pas déjà installé)
    if (-not(Get-Module -ListAvailable -Name PSWindowsUpdate)) 
    {
        Write-Host "Installation du module PSWindowsUpdate afin permettre les mises à jour sur PowerShell..." -ForegroundColor Cyan
        Install-Module -Name PSWindowsUpdate -Force -AllowClobber -Scope CurrentUser 

        Write-Log -Sévérité "INFO" -Contenu $_
        Write-Host "Installation du module terminée" -ForegroundColor Green
    }
    # Avant de lancer les mises à jour, vérifier que le poste est connecté à Internet 
    #Test-NetConnection 

    # Si le test échoue, demander au lanceur du script s'il désire toujours lancer les mises à jour Windows. Si oui, continuer l'exécution et sinon, sortir du script


    # Automatiser le lancement des mises à jour Windows et le redémarrage du système pour terminer les mises à jour restantes
    Write-Host "Lancement des mises à jour Windows Update..." -ForegroundColor Cyan
    Get-WindowsUpdate -Install -AcceptAll -AutoReboot -MicrosoftUpdate -RecurseCycle 10 

    Write-Log -Sévérité "INFO" -Contenu "Les mises à jour ont été installées avec succès" $_
    Write-Host "Les mises à jour ont été installées avec succès" -ForegroundColor Green
}

# Fonction 3 : Oublier tous les réseaux Wi-Fi connus sur l'ordinateur
function Remove-Network
{
    $liste_wifi = (netsh.exe wlan show profiles)
    foreach ($wifi in $liste_wifi) 
    {
        netsh.exe wlan delete profile $wifi
        #Write-Host "Réseau Wi-Fi $($wifi) oublié" -ForegroundColor Green
        Write-Log -Sévérité "INFO" -Contenu $_
    }
    Write-Host "Les réseaux Wi-Fi ont été oubliés avec succès" -ForegroundColor Green
}



# -------------------------------------------- Code principal --------------------------------------------



# Afficher le texte demandant de choisir quelle(s) fonction(s) appeler 
Write-Host "
Entrez le chiffre correspondant à l'option choisie :

1. Supprimer les utilisateurs désuets, lancer les mises à jour Windows et oublier tous les réseaux Wi-Fi
2. Lancer les mises à jour Windows et oublier tous les réseaux Wi-Fi
3. Lancer les mises à jour Windows
"
# Lire le chiffre entré par le lanceur du script
$choix_lancement = Read-Host "Entrez ici votre choix (1 à 3) "

# Exécuter les fonctions selon le chiffre entré par le lanceur du script
try 
{
    switch($choix_lancement)
    {
        "1" {Remove-Users ; Get-Update ; Remove-Network}
        "2" {Get-Update ; Remove-Network}
        "3" {Get-Update}
        default {Write-Host "Veuillez entrer un chiffre entre 1 et 3" -ForegroundColor Red}
    }
}
catch 
{
    Write-Host "Une erreur est survenue : " $_ -ForegroundColor Red
    Write-Log -Sévérité "ERREUR" -Contenu $_
}
