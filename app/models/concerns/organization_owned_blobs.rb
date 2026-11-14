module OrganizationOwnedBlobs
  extend ActiveSupport::Concern

  class_methods do
    def validates_organization_owned_blobs(attachments: [], rich_texts: [])
      validate -> { validate_organization_owned_blobs(attachments:, rich_texts:) }
    end
  end

  private
    def validate_organization_owned_blobs(attachments:, rich_texts:)
      target_organization_id = blob_owner_organization_id(self)

      attachments.each do |name|
        attached = public_send(name)
        next unless attached.attached?

        stamp_new_blob(attached.blob, target_organization_id)
        validate_blob_owner(attached.blob, name, target_organization_id)
      end

      rich_texts.each do |name|
        rich_text = public_send(name)
        next if rich_text.body.blank?

        rich_text.body.attachables.grep(ActiveStorage::Blob).uniq.each do |blob|
          validate_blob_owner(blob, name, target_organization_id)
        end

        # A mention attaches a Person; only the church's own People may appear.
        if rich_text.body.attachables.grep(Person).any? { |person| person.organization_id.to_s != target_organization_id.to_s }
          errors.add(name, "mentions someone from another church")
        end
      end
    end

    def validate_blob_owner(blob, attribute, target_organization_id)
      owner_id = blob.metadata["organization_id"]
      allowed = if owner_id.present?
        owner_id.to_s == target_organization_id.to_s
      else
        # Legacy blobs have no stamp, so accept them unless an existing attachment proves another church owns them.
        blob.attachments.all? do |attachment|
          attached_organization_id = blob_owner_organization_id(attachment.record)
          attached_organization_id.nil? || attached_organization_id.to_s == target_organization_id.to_s
        end
      end

      errors.add(attribute, "contains a file that belongs to another church") unless allowed
    end

    def stamp_new_blob(blob, organization_id)
      return unless blob.new_record? && blob.metadata["organization_id"].blank?

      blob.metadata = blob.metadata.merge("organization_id" => organization_id)
    end

    def blob_owner_organization_id(record)
      return blob_owner_organization_id(record.record) if record.is_a?(ActionText::RichText)
      return record.organization_id if record.respond_to?(:organization_id) && record.organization_id.present?
      record.project.organization_id if record.respond_to?(:project) && record.project.present?
    end
end
