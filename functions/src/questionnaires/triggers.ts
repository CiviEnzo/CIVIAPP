import * as admin from 'firebase-admin';
import type { QueryDocumentSnapshot } from 'firebase-admin/firestore';
import * as functions from 'firebase-functions';

const firestore = admin.firestore();
const TEMPLATES_COLLECTION = 'client_questionnaire_templates';
const QUESTIONNAIRES_COLLECTION = 'client_questionnaires';
const BATCH_LIMIT = 500;

export const onClientQuestionnaireTemplateWrite = functions.firestore
  .document(`${TEMPLATES_COLLECTION}/{templateId}`)
  .onWrite(async (change, context) => {
    const after = change.after.exists ? change.after.data() : null;
    if (!after) {
      return;
    }

    const templateId = context.params.templateId as string;
    const becameDefault = Boolean(after.isDefault);
    if (!becameDefault) {
      return;
    }

    const salonId = (after.salonId as string | undefined) ?? '';
    if (!salonId) {
      functions.logger.warn('Template marked as default without salonId', {
        templateId,
      });
      return;
    }

    const snapshot = await firestore
      .collection(TEMPLATES_COLLECTION)
      .where('salonId', '==', salonId)
      .where('isDefault', '==', true)
      .get();

    const batch = firestore.batch();
    let hasChanges = false;
    snapshot.docs.forEach((doc) => {
      if (doc.id !== templateId) {
        batch.update(doc.ref, { isDefault: false });
        hasChanges = true;
      }
    });

    if (hasChanges) {
      await batch.commit();
    }
  });

export const onClientQuestionnaireTemplateDelete = functions.firestore
  .document(`${TEMPLATES_COLLECTION}/{templateId}`)
  .onDelete(async (_snap, context) => {
    const templateId = context.params.templateId as string;
    const baseQuery = firestore
      .collection(QUESTIONNAIRES_COLLECTION)
      .where('templateId', '==', templateId);

    let lastDoc: QueryDocumentSnapshot | undefined;

    // Paginate through questionnaires to avoid exceeding batch limits.
    // eslint-disable-next-line no-constant-condition
    while (true) {
      let query = baseQuery.limit(BATCH_LIMIT);
      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }

      const snapshot = await query.get();
      if (snapshot.empty) {
        break;
      }

      const batch = firestore.batch();
      snapshot.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();

      lastDoc = snapshot.docs[snapshot.docs.length - 1];
    }
  });
