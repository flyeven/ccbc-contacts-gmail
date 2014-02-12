#ccbc-contacts-gmail

Push ccb individuals' contact information to your gmail contacts.

This will create a contact group in your gmail account called "{ccb subdomain}.ccb" and populate it with all of the individuals that have 'profile listing' enabled.  (In addition, these contacts will also be assigned to the system group "My Contacts" because this is the group that gmail uses when syncing contacts to phones.)

This is a three step process:

1. You will be redirected to google's website and prompted to allow this application access to

 * your gmail contacts (so we can update them)
 * your profile information (so we can know your name)
 * your email address (so we can identify your record in ccb)
 * offline access to your contacts (if you choose to resync periodically, so we can update them while you are sleeping)

2. We will look up your record in your ccb site based on your email address (to determine who and what you can see in order that we may respect individual's privacy settings) and confirm that you want to continue.

3. Contacts will get created or updated. (Only those contacts that we create will get updated. If you already have an existing contact with the same name in another group, it will NOT be touched.) When a contact record is updated, it is completely overwritten-- so if you make changes to these contact records on your phone, those changes will be lost. Instead, you should change them in ccb.

You can revoke the permissions that you've granted this application to your google account via the link at the bottom of each page (once you've authenticated).

##The General Idea
This was primarily designed for a church gmail account to have it's contacts sync'd each day with the information in CCB.  The church leadership would have this account on their mobile phones with contact importing/sharing turned on so that they would always have up to date contact information.

If you were going to have your church members sync to their own accounts, then you'd probably want to change this code to actually store the contact information locally in a database so that they could refresh from the local store instead of hitting your ccb site for syncing each of their accounts.  In this case, you'd probably NOT want your members to have to specify your CCB API information, but have it defaulted (like I do for my church).

If there is enough interest, I could turn this into a tenanted style service for each church that wants to do this. Let me know what you think.  Marvin - marvin.frederickson@gmail.com

